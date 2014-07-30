require 'json'

class Call

  Queues = ThreadSafe::Hash.new

  attr_accessor :channel1, :channel2, :target_id, :language,
                :called_at, :queued_at, :hungup_at, :dispatched_at,
                :skill, :hungup, :caller_id, :conn_line


  def initialize(par=nil)
    if par
      @target_id     = par.fetch(:target_id)
      @skill         = par.fetch(:skill, nil)
      @hungup        = par.fetch(:hungup, nil)
      @language      = par.fetch(:language, nil)
      @channel1      = par.fetch(:channel1, nil)
      @channel2      = par.fetch(:channel2, nil)
      @called_at     = par.fetch(:called_at, nil)
      @caller_id     = par.fetch(:caller_id, nil)
      @conn_line     = par.fetch(:conn_line, nil)
      @hungup_at     = par.fetch(:hungup_at, nil)
      @queued_at     = par.fetch(:queued_at, nil)
      @dispatched_at = par.fetch(:dispatched_at, nil)
    end
  end


  def headers
    {
      'Channel1' => channel1,  'Channel2' => channel2,  'Language'     => language,     'Skill'    => skill,
      'CallerId' => caller_id, 'Hungup'   => hungup,    'CalledAt'     => called_at,    'ConnLine' => conn_line,
      'QueuedAt' => queued_at, 'HungupAt' => hungup_at, 'DispatchedAt' => dispatched_at
    }
  end


  def save(expires=3.hours)
    $redis.set(Call.key_name(target_id), headers.to_json, ex: expires)
    publish_to_numbers
  end


  def destroy
    self.hungup    = true
    self.hungup_at = Call.current_time
    save(1.minute)
  end


  def publish_to_numbers
    event = {
      'target_call_id' =>  target_id,
      'timestamp'      =>  Call.current_time_ms,
      'name'           => 'CallUpdate',
      'headers'        =>  headers
    }

    AmqpManager.numbers_publish(event)
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


    def originate(data)
      from_a = User.where(name: data['from']).first
      from   = from_a ? "SIP/#{from_a.name}" : "SIP/#{data['from']}" # TODO Can we add the fullname here?
      to     = "SIP/#{data['to']}"

      Adhearsion::OutboundCall.originate(from, from: to) do
        dial to, from: from, for: 15.seconds
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


    def set_queued_at(tcid)
      call = find(tcid)
      call.queued_at = current_time
      call.save
    end


    def find(tcid)
      return unless tcid
      entry  = $redis.get(Call.key_name tcid) || new.headers.to_json
      fields = JSON.parse entry

      par = {
        target_id:     tcid,
        skill:         fields['Skill'],
        hungup:        fields['Hungup'],
        hungup_at:     fields['HungupAt'],
        called_at:     fields['CalledAt'],
        caller_id:     fields['CallerId'],
        channel1:      fields['Channel1'],
        channel2:      fields['Channel2'],
        language:      fields['Language'],
        queued_at:     fields['QueuedAt'],
        conn_line:     fields['ConnLine'],
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
      call.caller_id ||= (hdr['CallerIDName'] || hdr['CallerIDNum'])
      call.caller_id.force_encoding('UTF-8')

      call.called_at ||= current_time
    end


    def detect_channels_for(hdr, call)
      chan1 = hdr['Channel1'] || hdr['Channel']
      chan2 = hdr['Channel2']

      call.channel1    = chan1
      call.channel2    = chan2
      call.conn_line ||= connected_line_from(hdr)
    end


    # FIXME This doesn't work for agent-2-agent calls via direct_context:
    #
    def connected_line_from(hdr)
      hdr['ConnectedLineName'] || hdr['ConnectedLineNum']
    end


    def update_state_for(event)
      tcid = event.target_call_id
      call = Call.find(tcid)

      if call
        detect_callers_for(event.headers, call)
        detect_channels_for(event.headers, call)
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
