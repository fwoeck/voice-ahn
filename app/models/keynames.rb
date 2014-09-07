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
end
