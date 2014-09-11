# encoding: utf-8
require 'json'

class Call
  FORMAT = %w{target_id call_tag language skill extension caller_id hungup called_at mailbox queued_at hungup_at dispatched_at}
           .map(&:to_sym)

  attr_accessor *FORMAT

  Queues = ThreadSafe::Hash.new
  extend Keynames


  def initialize(par={})
    Call::FORMAT.each do |sym|
      self.send "#{sym}=", par.fetch(sym, nil)
    end
  end


  def save(expires=3.hours)
    dump = Marshal.dump(self)
    Redis.current.set(Call.call_keyname(target_id), dump, {ex: expires})
    publish(dump)
  end


  def destroy
    self.hungup    = true
    self.hungup_at = Time.now.utc
    save(1.minute)
  end


  def publish(dump)
    AmqpManager.publish(dump, mailbox_message?, true)
  end


  def mailbox_message?
    !mailbox.blank?
  end


  def update_state_for(hdr)
    detect_callers_for(hdr)
    detect_call_tag_for(hdr)
    detect_extension_for(hdr)
    save
  end


  def detect_callers_for(hdr)
    return if self.caller_id

    num = hdr['CallerIDNum']
    num = nil if (num.blank? || num == 'Anonymous')

    self.caller_id = (num || hdr['CallerIDName']).sub('SIP/', '')
    self.called_at = Time.now.utc
  end


  def detect_call_tag_for(hdr)
    chan1 = hdr['Channel1'] || hdr['Channel']
    chan2 = hdr['Channel2']

    if chan2
      self.call_tag = "#{chan1}_#{chan2}"
      self.dispatched_at ||= Time.now.utc
    end
  end


  def detect_extension_for(hdr)
    return if self.extension

    chan = hdr['Channel1'] || hdr['Channel'] || ""
    ext  = chan[ChannelRegex, 1] || '0'
    ext  = '0' if ext == AhnConfig.admin_name

    self.extension = ext
  end


  class << self

    def execute_command_with(data)
      case data[:command]
      when :hangup
        hangup(data)
      when :transfer
        transfer(data)
      when :originate
        originate(data)
      end
    end


    def call_to_trunk?(data)
      data[:to].length > 4
    end


    def originate(data)
      from = "SIP/#{data[:from]}"
      to   = "SIP/#{data[:to]}"
      to   = "#{data[:to]} <#{to}@sipconnect.sipgate.de>" if call_to_trunk?(data)

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
      execute_transfer(call, cdial, data[:to])
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
      cid = data[:call_id]
      Adhearsion.active_calls.values.find { |c| c.id == cid }
    end


    # TODO These should be calling instance methods:
    #
    def set_language_for(tcid, lang)
      find(tcid).tap { |c| c.language = lang }.save
    end


    def set_skill_for(tcid, skill)
      find(tcid).tap { |c| c.skill = skill }.save
    end


    def set_dispatched_at(tcid)
      find(tcid).tap { |c| c.dispatched_at = Time.now.utc }.save
    end


    def set_queued_at(tcid)
      find(tcid).tap { |c| c.queued_at = Time.now.utc }.save
    end


    def set_mailbox(tcid, mid)
      find(tcid).tap { |c| c.mailbox = mid }.destroy
    end


    def find(tcid)
      return unless tcid
      call = Redis.current.get(call_keyname tcid)
      Marshal.load(call) if call
    end


    def close_state_for(event)
      tcid = event.target_call_id
      call = Call.find(tcid)
      call.destroy if call
    end


    def update_state_for(event)
      tcid = event.target_call_id
      hdr  = event.headers
      call = Call.find(tcid) || Call.new(target_id: tcid)

      if call && !call.hungup
        call.update_state_for(hdr)
      end
    end


    def clear_all_redis_calls
      Redis.current.keys(call_keypattern).each { |key| Redis.current.del(key) }
    rescue Redis::CannotConnectError
      sleep 1
      retry
    end
  end
end
