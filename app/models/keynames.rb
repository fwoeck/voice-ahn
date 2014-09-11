module Keynames

  def availability_keyname
    "#{AhnConfig.rails_env}.availability.#{self.id}"
  end


  def availability_default
    :unknown
  end


  def activity_keyname
    "#{AhnConfig.rails_env}.activity.#{self.id}"
  end


  def activity_default
    :silent
  end


  def online_users_keyname
    "#{AhnConfig.rails_env}.online-users"
  end


  def call_keyname(tcid)
    "#{AhnConfig.rails_env}.call.#{tcid}"
  end


  def call_keypattern
    "#{AhnConfig.rails_env}.call.*"
  end
end
