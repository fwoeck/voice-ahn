require 'json'

class Call

  attr_accessor :channel1, :channel2, :target_id


  def initialize(tcid=nil, chan1=nil, chan2=nil)
    @target_id = tcid
    @channel1  = chan1
    @channel2  = chan2
  end


  def headers
    {'Channel1' => channel1, 'Channel2' => channel2}
  end


  def save
    $redis.set(Call.key_name(target_id), headers.to_json, ex: 1.day)
    # TODO Send out AMQP-message
  end


  def destroy
    $redis.del(Call.key_name target_id)
    # TODO Send out AMQP-message
  end


  def self.find(tcid)
    return unless tcid

    entry  = $redis.get(Call.key_name tcid) || new.headers.to_json
    fields = JSON.parse entry
    new(tcid, fields['Channel1'], fields['Channel2'])
  end


  def self.key_name(tcid)
    "#{WimConfig.rails_env}.call.#{tcid}"
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
      call.channel1 = event.headers['Channel1']
      call.channel2 = event.headers['Channel2']
      call.save
    end
  end


  def self.setup_new_state_for(event)
    tcid = event.target_call_id
    call = Call.find(tcid)

    if call
      call.channel1 = event.headers['Channel']
      call.save
    end
  end
end
