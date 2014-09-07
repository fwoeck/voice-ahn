module Keynames

  def availability_keyname
    "#{WimConfig.rails_env}.availability.#{self.id}"
  end


  def availability_default
    :unknown
  end


  def activity_keyname
    "#{WimConfig.rails_env}.activity.#{self.id}"
  end


  def activity_default
    :silent
  end


  def online_users_keyname
    "#{WimConfig.rails_env}.online-users"
  end


  def call_keyname(tcid)
    "#{WimConfig.rails_env}.call.#{tcid}"
  end


  def call_keypattern
    "#{WimConfig.rails_env}.call.*"
  end


  def current_time
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
  end


  def current_time_ms
    Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%L+00:00")
  end
end
