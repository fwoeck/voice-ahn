module AgentLocking

  def schedule_unlock
    s = self
    s.unlock_scheduled = true

    Thread.new {
      sleep IdleTimeout

      s.locked = false if agent_is_idle?
      s.unlock_scheduled = false
      s.idle_since = Time.now.utc
    }
  end


  def unlock_necessary?
    self.locked && !self.unlock_scheduled && agent_is_idle?
  end


  def agent_is_idle?
    self.activity == :silent
  end
end
