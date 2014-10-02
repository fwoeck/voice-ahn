require './app/models/agent'


module AgentCollector

  @@running = false


  class << self

    def unlock_idle_agents
      AgentRegistry.keys.each { |key|
        ag = AgentRegistry[key]
        ag.schedule_unlock if ag.unlock_necessary?
      }
    end


    def users_are_ready?
      defined?(User) && User.respond_to?(:ready?) && User.ready?
    end


    def start
      return if @@running
      @@running = true
      sleep 1 while !users_are_ready?

      Thread.new {
        while !User.shutdown? do
          sleep 1
          unlock_idle_agents
          Adhearsion.logger.debug AgentRegistry
        end
      }
    end
  end
end
