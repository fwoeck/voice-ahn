Dir['./app/models/*.rb'].each { |f| require f }

class User < Sequel::Model

  one_to_many :roles
  one_to_many :skills
  one_to_many :languages


  def availability
    @memo_availability ||= ($redis.get(Agent.availability_keyname self) || 'unknown')
  end


  def agent_state
    @memo_agent_state ||= ($redis.get(Agent.agent_state_keyname self) || 'unknown')
  end


  def self.fetch_all_agents
    all.each do |u|
      AgentRegistry[u.id] ||= AgentSettings.new(
        id:           u.id,
        name:         u.name,
        languages:    u.languages.map(&:name),
        skills:       u.skills.map(&:name),
        roles:        u.roles.map(&:name),
        availability: u.availability,
        agent_state:  u.agent_state,
        idle_since:   Time.now.utc,
        locked:      'false'
      )
    end
  end


  def self.all_ids
    self.select(:id).all.map(&:id)
  end
end


User.fetch_all_agents
