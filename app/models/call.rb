require 'json'

class Call

  attr_accessor :channel1, :channel2, :target_id, :language, :skill, :hungup


  def initialize(tcid=nil, chan1=nil, chan2=nil, lang=nil, skill=nil, hungup=nil)
    @target_id = tcid;  @hungup    = hungup
    @channel1  = chan1; @channel2  = chan2
    @language  = lang;  @skill     = skill
  end


  def headers
    {
      'Channel1' => channel1, 'Channel2' => channel2,
      'Language' => language, 'Skill'    => skill,
      'Hungup'   => hungup
    }
  end


  def current_time
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%L+00:00")
  end


  def save
    $redis.set(Call.key_name(target_id), headers.to_json, ex: 1.day)
    publish_to_numbers
  end


  def destroy
    self.hungup = true
    save
  end


  def publish_to_numbers
    event = {
      'target_call_id' =>  target_id,
      'timestamp'      =>  current_time,
      'name'           => 'CallUpdate',
      'headers'        =>  headers
    }

    AmqpManager.numbers_publish(event)
  end


  def self.find(tcid)
    return unless tcid
    entry  = $redis.get(Call.key_name tcid) || new.headers.to_json
    fields = JSON.parse entry

    new(tcid,
      fields['Channel1'], fields['Channel2'],
      fields['Language'], fields['Skill'],
      fields['Hungup']
    )
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
      call.channel1 = event.headers['Channel1'] || event.headers['Channel']
      call.channel2 = event.headers['Channel2']
      call.save
    end
  end
end
