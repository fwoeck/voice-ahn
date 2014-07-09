class Agent

  Registry = ThreadSafe::Hash.new
  State    = Struct.new(
               :id, :name, :languages, :skills, :roles,
               :availability, :callstate, :idle_since
             )

  class << self


    def find_agent_for(peer)
      (Agent::Registry.detect { |k, v| v.name == peer } || [nil, nil])[1]
    end


    def setup_current_callstate_for(agent, status)
      return unless agent && status

      agent.callstate = status
      $redis.set("#{WimConfig.rails_env}.callstate.#{agent.id}", status)
    end


    # Agent.where(availability: :ready, languages: :en).sort_by_idle_time
    #
    def where(hash)
      keys = hash.keys
      assert (keys.map(&:to_s) - WimConfig.keys) == [], hash
      filtered_agent_ids(keys, hash, User.all_ids)
    end


    def filtered_agent_ids(keys, hash, agent_ids)
      keys.each do |key|
        agent_ids = agent_ids.select { |uid|
          current_key_matches?(hash, key, uid)
        }
      end
      agent_ids
    end


    def current_key_matches?(hash, key, uid)
      value   = Registry[uid].send(key)
      request = hash[key].to_s

      value.is_a?(Array) ?
        value.include?(request) :
        value == request
    end


    def update_agent_state_with(payload)
      uid, key, value = get_key_value_pair(payload)

      if uid > 0 && key
        setter = "#{key}#{key[/y\z/] ? '' : 's'}="
        update_idle_since(key, value, uid)
        update_status_field(setter, value, uid)
      end
    end


    # FIXME This could be an instance method:
    #
    def update_status_field(setter, value, uid)
      Registry[uid].send setter, (value[/,/] ? value.split(',') : value)
      Adhearsion.logger.info "Update #{uid}'s state: #{setter}'#{value}'"
    end


    # FIXME This will not work - it requires to know
    #       the agent's talking state, too.
    #
    # FIXME This could be an instance method:
    #
    def update_idle_since(key, value, uid)
      if key == 'availability' && value == 'ready'
        Registry[uid].idle_since = Time.now.utc
      end
    end


    def get_key_value_pair(payload)
      data  = parsed_json(payload)
      uid   = data.delete('user_id').to_i # FIXME This could return an Agent instance
      key   = data.keys.first

      [uid, key, data[key]]
    end


    def parsed_json(payload)
      data = JSON.parse(payload)
      assert data.keys.include?('user_id'), payload
      assert data.keys.count == 2, payload
      data
    end


    def assert(value, payload)
      raise "Received invalid options: #{payload}" if !value
    end
  end
end
