require './app/models/agent'
require './app/models/call'


module CallScheduler

  @@running = false


  def self.waiting_calls
    Adhearsion.active_calls.keys.map { |cid|
      Call::Queues[cid]
    }.compact.select { |qcall|
      !qcall.answered
    }.sort { |x, y|
      x.queued_at <=> y.queued_at
    }
  end


  def self.start
    return if @@running
    @@running = true

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
