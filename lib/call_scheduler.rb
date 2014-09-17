require './app/models/agent'
require './app/models/call'


module CallScheduler

  @@running = false

  class << self

    def waiting_calls
      Adhearsion.active_calls.keys.map { |cid|
        Call::Queues[cid]
      }.compact.select { |call|
        !call.dispatched
      }.sort { |x, y|
        x.queued_at <=> y.queued_at
      }
    end


    def cleanup_call_mutexes
      (CallRegistry.keys - Adhearsion.active_calls.keys).each { |key|
        CallRegistry[key].terminate
        CallRegistry.delete(key)
      }
    end


    def schedule_calls_to_agents
      waiting_calls.each { |call|
        agent_id = Agent.where(languages: call.lang, skills: call.skill).sort_by_idle_time.first
        agent    = Agent.checkout(agent_id, call)

        if agent
          call.dispatched = true
          call.queue.push(agent)
          sleep 0.05
        end
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
          cleanup_call_mutexes
          schedule_calls_to_agents
        end
      }
    end
  end
end
