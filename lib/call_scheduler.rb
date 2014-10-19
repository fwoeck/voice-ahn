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
        if agent = Agent.checkout(agent_id_for(call), call)
          dispatch(call, agent)
        end
      }
    end


    def dispatch(call, agent)
      call.dispatched = true
      call.queue.push(agent)
      Adhearsion.logger.info "Schedule agent ##{agent.id} for #{call.call_id}"
      sleep 0.05
    end


    def agent_id_for(call)
      Agent.where(languages: call.language, skills: call.skill).sort_by_idle_time.first
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
          cleanup_call_mutexes
          schedule_calls_to_agents
        end
      }
    end
  end
end
