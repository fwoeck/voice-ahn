Dir['./app/models/*.rb'].each { |f| require f }


class User < Sequel::Model
  include Keynames

  one_to_many :skills
  one_to_many :languages

  @@ready    = false
  @@shutdown = false


  def availability
    @memo_availability ||= (
      Redis.current.get(availability_keyname) || availability_default
    )
  end


  def activity
    @memo_activity ||= (
      Redis.current.get(activity_keyname) || activity_default
    )
  end


  def visibility
    @memo_visibility ||= (
      Redis.current.sismember(online_users_keyname, id) ? :online : :offline
    )
  end


  def build_agent
    Redis.current.set(activity_keyname, activity_default)

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
