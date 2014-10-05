Dir['./app/models/*.rb'].each { |f| require f }

class User < Sequel::Model
  include UserFields
  include Keynames

  @@ready    = false
  @@shutdown = false


  def build_agent
    RPool.with { |con| con.set(activity_keyname, activity_default) }

    AgentRegistry[id] = Agent.new(
      id:           id,
      name:         name,
      locked:       false,
      skills:       skills,
      languages:    languages,
      idle_since:   Time.now.utc,
      activity:     activity.to_sym,
      visibility:   visibility.to_sym,
      availability: availability.to_sym
    )
  end


  class << self

    def fetch_all_agents
      all.each { |user| user.build_agent }
      @@ready = true
    rescue Redis::CannotConnectError
      sleep 1
      retry
    end


    def shutdown
      @@shutdown = true
    end


    def shutdown?
      @@shutdown
    end


    def ready?
      @@ready
    end


    def all_ids
      self.select(:id).all.map(&:id)
    end
  end
end
