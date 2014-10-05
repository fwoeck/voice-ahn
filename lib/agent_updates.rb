module AgentUpdates

  def update_setting(key, value)
    self.send "#{key}=", value

    if key == :visibility
      persist_visibility_with(value)
      publish_update
    end
    Adhearsion.logger.info "Set ##{id}'s #{key} to \"#{value}\""
  end


  def update_activity_to(act)
    return if !act || act == activity

    self.mutex.synchronize {
      update_internal_activity(act) && persist_activity_with(act)
    }
  end


  def persist_visibility_with(vis)
    verb = (vis == :online ? :sadd : :srem)
    RPool.with { |con| con.send(verb, online_users_keyname, id) }
  end


  def persist_activity_with(act)
    RPool.with { |con| con.set(activity_keyname, act, {ex: 1.week}) }
    return true
  end


  def update_internal_activity(new_act)
    if self.activity != new_act
      self.activity = new_act
      return true
    end
  end


  def publish_update(tcid=nil)
    agent = Agent.new.tap { |a|
      a.id         = id
      a.name       = name
      a.skills     = skills
      a.call_id    = tcid
      a.activity   = activity
      a.languages  = languages
      a.visibility = visibility
    }

    AmqpManager.publish(
      Marshal.dump(agent), agent.takes_call?, agent.log_event?
    )
  end


  def log_event?
    activity == :talking
  end


  def takes_call?
    [:ringing, :talking].include?(activity) && name != AhnConfig.admin_name
  end
end
