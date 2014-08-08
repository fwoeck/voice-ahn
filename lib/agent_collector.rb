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


    def wait_for_user_ready
      sleep 1 while !(defined?(User) && User.ready?)
    end


    def start
      return if @@running
      @@running = true

      wait_for_user_ready

      Thread.new {
        while !User.shutdown? do
          sleep 1
          unlock_idle_agents
        end
      }
    end
  end
end
