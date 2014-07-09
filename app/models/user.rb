Dir['./app/models/*.rb'].each { |f| require f }

class User < Sequel::Model

  one_to_many :roles
  one_to_many :skills
  one_to_many :languages


  def availability
    $redis.get(availability_keyname) || 'unknown'
  end


  def callstate
    $redis.get(callstate_keyname) || 'unknown'
  end


  def self.fetch_all_agents
    all.each do |u|
      Agent::Registry[u.id] = Agent::State.new(
        u.id, u.name, u.languages.map(&:name),
        u.skills.map(&:name), u.roles.map(&:name),
        u.availability, u.callstate, Time.now.utc
      )
    end
  end


  def self.all_ids
    self.select(:id).all.map(&:id)
  end


  private

  def availability_keyname
    "#{WimConfig.rails_env}.availability.#{self.id}"
  end

  def callstate_keyname
    "#{WimConfig.rails_env}.callstate.#{self.id}"
  end
end

User.fetch_all_agents
