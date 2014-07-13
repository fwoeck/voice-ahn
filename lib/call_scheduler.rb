require './app/models/agent'
require './app/models/call'


module CallScheduler

  def self.waiting_calls
    Adhearsion.active_calls.keys.map { |cid|
      Call::Queues[cid]
    }.compact.select { |c|
      !c.answered
    }.sort { |x, y|
      y.queued_at <=> x.queued_at
    }
  end


  def self.start
    Thread.new {
      while true do
        sleep 1

        waiting_calls.each { |call|
          agent_id = Agent.where(languages: call.lang, skills: call.skill).sort_by_idle_time.first
          agent    = Agent.checkout(agent_id)

          call.queue.push(agent) if agent
        }
      end
    }
  end
end

CallScheduler.start
