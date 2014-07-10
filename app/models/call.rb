require 'json'

class Call

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
      'Channel1' => channel1, 'Channel2' => channel2, 'Language' => language, 'Skill' => skill,
      'CallerId' => caller_id, 'Hungup' => hungup, 'Initiator' => initiator, 'CalledAt' => called_at,
      'QueuedAt' => queued_at, 'HungupAt' => hungup_at, 'DispatchedAt' => dispatched_at
    }
  end


  def save
    $redis.set(Call.key_name(target_id), headers.to_json, ex: 3.hours)
    publish_to_numbers
  end


  def destroy
    self.hungup    = true
    self.hungup_at = Call.current_time
    save
  end


  def publish_to_numbers
    event = {
      'target_call_id' =>  target_id,
      'timestamp'      =>  Call.current_time,
      'name'           => 'CallUpdate',
      'headers'        =>  headers
    }

    AmqpManager.numbers_publish(event)
  end


  def self.find(tcid)
    return unless tcid
    entry  = $redis.get(Call.key_name tcid) || new.headers.to_json
    fields = JSON.parse entry

    par = {
      called_at:     fields['CalledAt'],
      caller_id:     fields['CallerId'],
      channel1:      fields['Channel1'],
      channel2:      fields['Channel2'],
      dispatched_at: fields['DispatchedAt'],
      hungup:        fields['Hungup'],
      hungup_at:     fields['HungupAt'],
      initiator:     fields['Initiator'],
      language:      fields['Language'],
      queued_at:     fields['QueuedAt'],
      skill:         fields['Skill'],
      target_id:     tcid
    }

    new(par)
  end


  def self.key_name(tcid)
    "#{WimConfig.rails_env}.call.#{tcid}"
  end


  def self.current_time
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%L+00:00")
  end


  def self.close_state_for(event)
    tcid = event.target_call_id
    call = Call.find(tcid)
    call.destroy if call
  end


  def self.update_state_for(event)
    tcid = event.target_call_id
    call = Call.find(tcid)

    if call
      call.caller_id = call.caller_id || event.headers['CallerIDNum']
      call.called_at = call.called_at || current_time

      call.channel1  = event.headers['Channel1'] || event.headers['Channel']
      call.channel2  = event.headers['Channel2']

      if event['name'] == 'Newstate' && call.channel1.include?(call.caller_id)
        call.initiator = true
      end
      call.save
    end
  end
end
