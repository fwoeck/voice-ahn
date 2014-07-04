require './app/models/agent'

class User < Sequel::Model

  one_to_many :roles
  one_to_many :skills
  one_to_many :languages


  def availability
    $redis.get(availability_keyname) || 'unknown'
  end


  def self.fetch_all_agents
    all.each do |u|
      Agent::Registry[u.id] = Agent::State.new(
        u.languages.map(&:name),
        u.skills.map(&:name),
        u.roles.map(&:name),
        u.availability
      )
    end
  end


  private

  def availability_keyname
    "#{WimConfig.rails_env}.availability.#{self.id}"
  end
end

User.fetch_all_agents
