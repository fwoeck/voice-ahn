module AgentHelpers

  def extract_from(call)
    get_by_name(call.to[ChannelRegex, 1] || call.from[ChannelRegex, 1])
  end


  def get_by_name(peer)
    (AgentRegistry.detect { |k, v| v.name == peer } || [nil, nil])[1] if peer
  end


  def get_peer_from(event)
    peer = event.headers['Peer'] || event.headers['Channel']
    peer[ChannelRegex, 1] if peer
  end


  def set_availability_scope(hash)
    hash[:locked]       =  false
    hash[:activity]     = :silent
    hash[:visibility]   = :online
    hash[:availability] = :ready
  end


  def filtered_agent_ids(keys, hash)
    keys.inject(all_ids) do |agent_ids, key|
      agent_ids = agent_ids.select { |uid|
        current_key_matches?(hash, key, uid)
      }
    end
  end


  def current_key_matches?(hash, key, uid)
    return false unless AgentRegistry[uid]

    value   = AgentRegistry[uid].send(key)
    request = hash[key].to_s

    value.is_a?(Array) ?
      value.include?(request) :
      value.to_s == request
  end


  def assert(value, data)
    raise "Received invalid options: #{data}" if !value
  end
end
