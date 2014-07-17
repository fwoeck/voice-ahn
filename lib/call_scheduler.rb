require './app/models/agent'
require './app/models/call'


module CallScheduler

  @@running = false


  def self.waiting_calls
    Adhearsion.active_calls.keys.map { |cid|
      Call::Queues[cid]
    }.compact.select { |call|
      !call.answered
    }.sort { |x, y|
      x.queued_at <=> y.queued_at
    }
  end


  def self.schedule_calls_to_agents
    waiting_calls.each { |call|
      agent_id = Agent.where(languages: call.lang, skills: call.skill).sort_by_idle_time.first
      puts ">>> checkout #{agent_id} for #{call}" if agent_id
      agent    = Agent.checkout(agent_id)

      if agent
        call.answered = true
        call.queue.push(agent)
        sleep 0.05
      end
    }
  end


  def self.start
    return if @@running
    @@running = true

    Thread.new {
      while true do
        sleep 1
        schedule_calls_to_agents
      end
    }
  end
end

CallScheduler.start
