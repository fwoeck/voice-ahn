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
      Agent::Registry[u.id] = Agent::State.new(u.id, u.name,
        u.languages.map(&:name), u.skills.map(&:name), u.roles.map(&:name),
        u.availability, u.agent_state, Time.now.utc, 'false'
      )
    end
  end


  def self.all_ids
    self.select(:id).all.map(&:id)
  end
end


User.fetch_all_agents
