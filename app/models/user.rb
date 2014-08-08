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


  def agent_reg_keyname
    "#{WimConfig.rails_env}.agent_reg.#{self.id}"
  end


  def availability
    @memo_availability ||= ($redis.get(availability_keyname) || :unknown)
  end


  def agent_state
    @memo_agent_state ||= ($redis.get(agent_state_keyname) || :silent)
  end


  def agent_reg
    @memo_agent_reg ||= ($redis.get(agent_reg_keyname) || :unknown)
  end


  def self.fetch_all_agents
    all.each do |user|
      $redis.set(user.agent_state_keyname, :silent)
      $redis.set(user.agent_reg_keyname, :unknown)
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
      roles:        u.roles.map(&:name),
      skills:       u.skills.map(&:name),
      agent_reg:    u.agent_reg.to_sym,
      agent_state:  u.agent_state.to_sym,
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
