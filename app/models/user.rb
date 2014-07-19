Dir['./app/models/*.rb'].each { |f| require f }


class User < Sequel::Model

  one_to_many :roles
  one_to_many :skills
  one_to_many :languages

  @@ready    = false
  @@shutdown = false


  def availability_keyname
    "#{WimConfig.rails_env}.availability.#{self.id}"
  end


  def agent_state_keyname
    "#{WimConfig.rails_env}.agent_state.#{self.id}"
  end


  def availability
    @memo_availability ||= ($redis.get(availability_keyname) || 'unknown')
  end


  def agent_state
    @memo_agent_state ||= ($redis.get(agent_state_keyname) || 'unknown')
  end


  def self.fetch_all_agents
    all.each do |u|
      AgentRegistry[u.id] ||= Agent.new(
        id:           u.id,
        name:         u.name,
        languages:    u.languages.map(&:name),
        skills:       u.skills.map(&:name),
        roles:        u.roles.map(&:name),
        availability: u.availability,
        agent_state:  u.agent_state,
        idle_since:   Time.now.utc,
        locked:       false
      )
    end

    @@ready = true
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
