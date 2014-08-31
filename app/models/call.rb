# encoding: utf-8
require 'json'

class Call

  Queues = ThreadSafe::Hash.new

  attr_accessor :call_tag, :target_id, :language, :extension,
                :called_at, :queued_at, :hungup_at, :dispatched_at,
                :skill, :hungup, :caller_id, :mailbox


  def initialize(par=nil)
    if par
      @target_id     = par.fetch(:target_id)
      @skill         = par.fetch(:skill, nil)
      @hungup        = par.fetch(:hungup, nil)
      @mailbox       = par.fetch(:mailbox, nil)
      @language      = par.fetch(:language, nil)
      @call_tag      = par.fetch(:call_tag, nil)
      @called_at     = par.fetch(:called_at, nil)
      @caller_id     = par.fetch(:caller_id, nil)
      @hungup_at     = par.fetch(:hungup_at, nil)
      @queued_at     = par.fetch(:queued_at, nil)
      @extension     = par.fetch(:extension, nil)
      @dispatched_at = par.fetch(:dispatched_at, nil)
    end
  end


  def headers
    {
      'CallTag'  => call_tag,  'Language' => language,  'Skill'        => skill,     'Extension' => extension,
      'CallerId' => caller_id, 'Hungup'   => hungup,    'CalledAt'     => called_at, 'Mailbox'   => mailbox,
      'QueuedAt' => queued_at, 'HungupAt' => hungup_at, 'DispatchedAt' => dispatched_at
    }
  end


  def save(expires=3.hours)
    $redis.set(Call.key_name(target_id), headers.to_json, ex: expires)
    publish
  rescue JSON::GeneratorError, Encoding::UndefinedConversionError
    # FIXME The callerId's encoding is ASCII when coming from the event.
    #       When the it contains UTF-8 chars, this leads to malformed strings.
    #
    Adhearsion.logger.error "An encoding-error happened for #{headers}"
  end


  def destroy
    self.hungup    = true
    self.hungup_at = Call.current_time
    save(1.minute)
  end


  def publish
    event = {
      'target_call_id' =>  target_id,
      'timestamp'      =>  Call.current_time_ms,
      'name'           => 'CallState',
      'headers'        =>  headers
    }

    AmqpManager.publish(event)
  end


  class << self

    def execute_command_with(data)
      case data['command']
      when 'hangup'
        hangup(data)
      when 'transfer'
        transfer(data)
      when 'originate'
        originate(data)
      end
    end


    def call_to_trunk?(data)
      data['to'].length > 4
    end


    def originate(data)
      from = "SIP/#{data['from']}"
      to   = "SIP/#{data['to']}"
      to   = "#{data['to']} <#{to}@sipconnect.sipgate.de>" if call_to_trunk?(data)

      # FIXME Transfer of a call originated by us will fail, because
      #       a controller is needed to store the metadata:
      #
      Adhearsion::OutboundCall.originate(from, from: to) do
        opts = {for: DialTimeout.seconds}
        opts[:from] = from unless call_to_trunk?(data)
        dial to, opts
      end
    end


    def transfer(data)
      call = find_ahn_call_for(data)
      call.auto_hangup = false

      cdial = call.controllers.first.metadata['current_dial']
      execute_transfer(call, cdial, data['to'])
    end


    def execute_transfer(call, cdial, to)
      call.execute_controller do
        begin
          cdial.cleanup_calls
          tdial = Adhearsion::CallController::Dial::Dial.new("SIP/#{to}", {}, call)
          metadata['current_dial'] = tdial

          tdial.run self
          tdial.await_completion
          tdial.cleanup_calls
        ensure
          hangup
        end
      end
    end


    def hangup(data)
      if call = find_ahn_call_for(data)
        call.pause_controllers
        call.hangup
      end
    end


    def find_ahn_call_for(data)
      cid = data['call_id']
      Adhearsion.active_calls.values.find { |c| c.id == cid }
    end


    def set_language_for(tcid, lang)
      call = find(tcid)
      call.language = lang
      call.save
    end


    def set_skill_for(tcid, skill)
      call = find(tcid)
      call.skill = skill
      call.save
    end


    def set_dispatched_at(tcid)
      call = find(tcid)
      call.dispatched_at = current_time
      call.save
    end


    def set_queued_at(tcid)
      call = find(tcid)
      call.queued_at = current_time
      call.save
    end


    def set_mailbox(tcid, mid)
      call = find(tcid)
      call.mailbox = mid
      call.destroy
    end


    def find(tcid)
      return unless tcid
      entry  = $redis.get(Call.key_name tcid) || new.headers.to_json
      fields = JSON.parse entry

      par = {
        target_id:     tcid,
        skill:         fields['Skill'],
        hungup:        fields['Hungup'],
        mailbox:       fields['Mailbox'],
        call_tag:      fields['CallTag'],
        hungup_at:     fields['HungupAt'],
        called_at:     fields['CalledAt'],
        caller_id:     fields['CallerId'],
        language:      fields['Language'],
        queued_at:     fields['QueuedAt'],
        extension:     fields['Extension'],
        dispatched_at: fields['DispatchedAt']
      }

      new(par)
    end


    def key_name(tcid)
      "#{WimConfig.rails_env}.call.#{tcid}"
    end


    def current_time
      Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    end


    def current_time_ms
      Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%L+00:00")
    end


    def close_state_for(event)
      tcid = event.target_call_id
      call = Call.find(tcid)
      call.destroy if call
    end


    def detect_callers_for(hdr, call)
      return if call.caller_id

      num = hdr['CallerIDNum']
      num = nil if (num.blank? || num == 'Anonymous')
      num = "SIP/#{num}" if (num && num[/^\d\d\d\d?$/])

      call.caller_id = num || hdr['CallerIDName']
      call.called_at = current_time
    end


    def detect_extension_for(hdr, call)
      return if call.extension

      chan = hdr['Channel1'] || hdr['Channel'] || ""
      ext  = chan[ChannelRegex, 1] || '0'
      ext  = '0' if ext == WimConfig.admin_name

      call.extension = ext
    end


    def detect_call_tag_for(hdr, call)
      chan1 = hdr['Channel1'] || hdr['Channel']
      chan2 = hdr['Channel2']

      if chan2
        call.call_tag = "#{chan1}_#{chan2}"
        call.dispatched_at ||= current_time
      end
    end


    def update_state_for(event)
      tcid = event.target_call_id
      hdr  = event.headers
      call = Call.find(tcid)

      if call && !call.hungup
        detect_callers_for(hdr, call)
        detect_call_tag_for(hdr, call)
        detect_extension_for(hdr, call)
        call.save
      end
    end


    def clear_all_redis_calls
      $redis.keys("#{WimConfig.rails_env}.call.*").each { |key| $redis.del(key) }
    rescue Redis::CannotConnectError
      sleep 1
      retry
    end
  end
end
