require './app/models/agent'


StateHistory = ThreadSafe::Hash.new
StateStruct  = Struct.new(:last_state)
IdleTimeout  = 3


module AgentCollector

  @@running = false

  class << self


    def unlock_idle_agents
      AgentRegistry.keys.each { |key|
        sh = StateHistory[key]
        ag = AgentRegistry[key]

        if agent_changed_to_idle?(ag)
          schedule_unlock(ag)
        end
        sh.last_state = ag.agent_state
      }
    end


    def schedule_unlock(ag)
      return if     ag.unlock_scheduled
      return unless ag.locked

      Thread.new {
        ag.unlock_scheduled = true
        sleep IdleTimeout

        ag.locked = false
        ag.unlock_scheduled = false
        ag.idle_since = Time.now.utc
      }
    end


    def agent_changed_to_idle?(ag)
      ag.locked && ag.agent_state == 'registered'
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
