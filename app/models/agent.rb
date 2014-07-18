require './app/models/agent_settings'

AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP.(\d+)/


class Agent
  class << self


    def all_ids
      AgentRegistry.keys.uniq
    end


    def get_peer_from(event)
      peer = event.headers['Peer'] || event.headers['Channel']
      peer[ChannelRegex, 1] if peer
    end


    def availability_keyname(agent)
      "#{WimConfig.rails_env}.availability.#{agent.id}"
    end


    def agent_state_keyname(agent)
      "#{WimConfig.rails_env}.agent_state.#{agent.id}"
    end


    def find_for(event)
      peer = get_peer_from(event)
      (AgentRegistry.detect { |k, v| v.name == peer } || [nil, nil])[1] if peer
    end


    # Possible states are "registered", "unregistered" and "talking":
    #
    def update_state_for(agent, state)
      return unless agent && state

      agent.mutex.synchronize {
        update_internal_model(agent, state) &&
          persist_state_for(agent, state)
      }
    end


    def persist_state_for(agent, state)
      $redis.set(agent_state_keyname(agent), state)
      return true
    end


    def update_internal_model(agent, new_state)
      old_state = agent.agent_state

      if old_state != new_state
        agent.agent_state = new_state
        agent.idle_since  = Time.now.utc if old_state == 'talking'

        # if agent.locked == 'true' && new_state != 'talking'
        #   checkin_agent(agent.id)
        # end
        return true
      end
    end


    def checkin_agent(agent_id)
      puts ">>> queue unlock #{agent_id}"
      Thread.new {
        sleep 3
        checkin(agent_id)
      }
    end


    def checkout(agent_id, call)
      return false unless agent_id

      agent = AgentRegistry[agent_id]
      puts ">>> lock #{agent.id} for #{call}"
      agent.locked = 'true'
      agent
    end


    def checkin(agent_id)
      agent = AgentRegistry[agent_id]
      puts ">>> unlock #{agent.id}"
      agent.locked = 'false'
    end


    def where(hash)
      set_availability_scope(hash)
      keys = hash.keys

      assert (keys.map(&:to_s) - WimConfig.keys) == [], hash
      filtered_agent_ids(keys, hash)
    end


    def set_availability_scope(hash)
      hash[:locked]       = 'false'
      hash[:agent_state]  = 'registered'
      hash[:availability] = 'ready'
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
        value == request
    end


    # The redisDB entries have already been set by VR,
    # so we just have to update our memory model:
    #
    def update_client_settings_with(data)
      uid, key, value = get_agent_value_pair(data)

      if uid > 0 && key
        setter = "#{key}#{key[/y\z/] ? '' : 's'}="
        update_user_setting(setter, value, uid)
      end
    end


    # TODO We should use real Agent instances here:
    #
    def update_user_setting(setter, value, uid)
      AgentRegistry[uid].send setter, (value[/,/] ? value.split(',') : value)
      Adhearsion.logger.info "Update #{uid}'s setting: #{setter}'#{value}'"
    end


    # TODO We should use real Agent instances here:
    #
    def get_agent_value_pair(data)
      uid = data.delete('user_id').to_i
      key = data.keys.first

      [uid, key, data[key]]
    end


    def assert(value, data)
      raise "Received invalid options: #{data}" if !value
    end
  end
end
