require 'json'

class Call

  Queues = ThreadSafe::Hash.new

  attr_accessor :channel1, :channel2, :target_id, :language,
                :called_at, :queued_at, :hungup_at, :dispatched_at,
                :skill, :hungup, :caller_id, :initiator


  def initialize(par=nil)
    if par
      @called_at     = par.fetch(:called_at, nil)
      @caller_id     = par.fetch(:caller_id, nil)
      @channel1      = par.fetch(:channel1, nil)
      @channel2      = par.fetch(:channel2, nil)
      @dispatched_at = par.fetch(:dispatched_at, nil)
      @hungup        = par.fetch(:hungup, nil)
      @hungup_at     = par.fetch(:hungup_at, nil)
      @initiator     = par.fetch(:initiator, nil)
      @language      = par.fetch(:language, nil)
      @queued_at     = par.fetch(:queued_at, nil)
      @skill         = par.fetch(:skill, nil)
      @target_id     = par.fetch(:target_id)
    end
  end


  def headers
    {
      'Channel1' => channel1,  'Channel2' => channel2,  'Language'     => language,  'Skill'    => skill,
      'CallerId' => caller_id, 'Hungup'   => hungup,    'Initiator'    => initiator, 'CalledAt' => called_at,
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
      to     = data['to']

      Adhearsion::OutboundCall.originate(
        "SIP/#{to}", from: from, controller: DirectContext
      )
    end


    def transfer(data)
      call = find_ahn_call_for(data)
      cc   = call.controllers.first
      cd   = cc.metadata['current_dial']

      call.execute_controller {
        td = Adhearsion::CallController::Dial::Dial.new("SIP/#{data['to']}", {}, call)

        td.skip_cleanup
        cd.skip_cleanup
        td.run(self)
        cd.merge td

        td.await_completion
        td.cleanup_calls
      }
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
        initiator:     fields['Initiator'],
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
      call.caller_id = call.caller_id || hdr['CallerIDName']
      call.caller_id.force_encoding('UTF-8')

      call.called_at = call.called_at || current_time
    end


    def detect_channels_for(hdr, call)
      chan  = hdr['Channel']
      chan1 = hdr['Channel1']
      chan2 = hdr['Channel2']

      call.channel1 = call.channel1 || chan1 || chan
      update_initiator_for(chan1, chan2, call)
    end


    def update_initiator_for(chan1, chan2, call)
      if chan2
        call.channel2 = call.channel2 || (call.channel1 == chan1 ? chan2 : chan1)
      else
        call.initiator = true if call.channel1[/sipgate|skype|SIP.100-/]
      end
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
