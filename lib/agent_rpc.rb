module AgentRpc

  def handle_message
    key, value = get_agent_value_pair
    agent = AgentRegistry[id]

    if agent && key
      agent.update_setting(key, value)
    else
      synch_agent_from_db(agent, id)
    end
  end


  def get_agent_value_pair
    ivar = instance_variables.reject { |v| v == :@id }.first
    key  = ivar ? ivar.to_s.sub('@', '').to_sym : nil
    val  = key  ? self.send(key) : nil

    [key, val]
  end


  def synch_agent_from_db(agent, uid)
    ext = nil

    if (db_user = User[uid])
      ext = db_user.name
      db_user.build_agent
    elsif agent
      ext = agent.name
      AgentRegistry.delete uid
    end

    reload_asterisk_sip_peer(ext)
  end


  def reload_asterisk_sip_peer(ext)
    return unless ext
    system("sudo asterisk -rx 'sip prune realtime #{ext}' >/dev/null")
    Adhearsion.logger.info "Update asterisk peer extension #{ext}"
  end
end
