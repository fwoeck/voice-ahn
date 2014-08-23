Dir['./app/models/*.rb'].each { |f| require f }


class User < Sequel::Model

  one_to_many :skills
  one_to_many :languages

  @@ready    = false
  @@shutdown = false


  def availability_keyname
    "#{WimConfig.rails_env}.availability.#{self.id}"
  end


  def activity_keyname
    "#{WimConfig.rails_env}.activity.#{self.id}"
  end


  def visibility_keyname
    "#{WimConfig.rails_env}.visibility.#{self.id}"
  end


  def availability
    @memo_availability ||= ($redis.get(availability_keyname) || :unknown)
  end


  def activity
    @memo_activity ||= ($redis.get(activity_keyname) || :silent)
  end


  def visibility
    @memo_visibility ||= ($redis.get(visibility_keyname) || :offline)
  end


  def self.fetch_all_agents
    all.each do |user|
      $redis.set(user.activity_keyname, :silent)
      build_from(user)
    end

    @@ready = true
  rescue Redis::CannotConnectError
    sleep 1
    retry
  end


  def self.build_from(u)
    AgentRegistry[u.id] ||= Agent.new(
      id:           u.id,
      locked:       false,
      name:         u.name,
      idle_since:   Time.now.utc,
      skills:       u.skills.map(&:name),
      activity:     u.activity.to_sym,
      visibility:   u.visibility.to_sym,
      availability: u.availability.to_sym,
      languages:    u.languages.map(&:name)
    )
  end


  def self.shutdown!
    @@shutdown = true
  end


  def self.shutdown?
    @@shutdown
  end


  def self.ready?
    @@ready
  end


  def self.all_ids
    self.select(:id).all.map(&:id)
  end
end
