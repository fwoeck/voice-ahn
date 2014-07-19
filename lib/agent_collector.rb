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
        tn = Time.now.utc

        update_agent_history(ag, sh, tn)
        sh.last_state = ag.agent_state
      }
    end


    def update_agent_history(ag, sh, tn)
      if agent_changed_to_registered?(ag, sh)
        ag.idle_since = tn
        # puts ">>> agent changed to registered #{ag.id}"
        schedule_unlock(ag) if ag.locked == 'true'
      end
    end


    def schedule_unlock(ag)
      Thread.new {
        sleep IdleTimeout
        # puts ">>> agent unlocked #{ag.id}"
        ag.locked = 'false'
      }
    end


    def agent_changed_to_registered?(ag, sh)
      # puts ">>> #{ag.id} old state: #{sh.last_state}, new state: #{ag.agent_state}" if sh.last_state != ag.agent_state
      (ag.locked == 'true' || sh.last_state != 'registered') &&
        ag.agent_state == 'registered'
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
