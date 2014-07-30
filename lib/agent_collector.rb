require './app/models/agent'


StateHistory = ThreadSafe::Hash.new
StateStruct  = Struct.new(:last_state)


module AgentCollector

  @@running = false


  class << self

    def unlock_idle_agents
      AgentRegistry.keys.each { |key|
        sh = StateHistory[key]
        ag = AgentRegistry[key]

        ag.schedule_unlock if ag.unlock_necessary?
        sh.last_state = ag.agent_state
      }
    end


    def initialize_state_history
      AgentRegistry.keys.each { |key|
        StateHistory[key] = StateStruct.new(nil)
      }
    end


    def wait_for_user_ready
      sleep 1 while !(defined?(User) && User.ready?)
    end


    def start
      return if @@running
      @@running = true

      wait_for_user_ready
      initialize_state_history

      Thread.new {
        while !User.shutdown? do
          sleep 1
          unlock_idle_agents
        end
      }
    end
  end
end
