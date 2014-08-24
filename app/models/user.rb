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


  def build_agent
    $redis.set(activity_keyname, :silent)

    AgentRegistry[id] = Agent.new(
      id:           id,
      locked:       false,
      name:         name,
      idle_since:   Time.now.utc,
      skills:       skills.map(&:name),
      activity:     activity.to_sym,
      visibility:   visibility.to_sym,
      availability: availability.to_sym,
      languages:    languages.map(&:name)
    )
  end


  def self.fetch_all_agents
    all.each { |user| user.build_agent }
    @@ready = true
  rescue Redis::CannotConnectError
    sleep 1
    retry
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
