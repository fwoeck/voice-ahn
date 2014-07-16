class Agent

  ChannelRegex = /^SIP.(\d+)/
  Registry     = ThreadSafe::Hash.new
  State        = Struct.new(
                   :id, :name, :languages, :skills, :roles, :availability,
                   :agent_state, :idle_since, :locked
                 )

  class << self


    def all_ids
      Registry.keys.uniq
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
      (Agent::Registry.detect { |k, v| v.name == peer } || [nil, nil])[1] if peer
    end


    # Possible states are "registered", "unregistered" and "talking":
    #
    def update_state_for(agent, status)
      return unless agent && status

      if agent.agent_state != status
        update_internal_model(agent, status)
        $redis.set(agent_state_keyname(agent), status)
        return true
      end

      false
    end


    def update_internal_model(agent, status)
      agent.agent_state = status

      if status == 'registered'
        agent.idle_since = Time.now.utc
        checkin_agent(agent.id)
      end
    end


    def checkin_agent(agent_id)
      puts ">>> want to checkin #{agent_id}"
      Thread.new {
        sleep 3
        checkin(agent_id)
      }
    end


    def checkout(agent_id)
      return false unless agent_id
      agent = Registry[agent_id]

      return false if agent.locked == 'true'
      agent.locked = 'true'

      puts ">>> checkout #{agent_id}"
      agent
    end


    def checkin(agent_id)
      agent = Registry[agent_id]
      puts ">>> checkin failed not agent for #{agent_id}" unless agent
      if agent.locked == 'true'
        puts ">>> checkin #{agent_id}"
        agent.locked = 'false'
      else
        puts ">>> checkin failed #{agent_id}, was: #{agent.locked}"
      end
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
      return false unless Registry[uid]

      value   = Registry[uid].send(key)
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
      Registry[uid].send setter, (value[/,/] ? value.split(',') : value)
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
