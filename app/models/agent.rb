AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP\/(\d+)/
IdleTimeout   = 3


class Agent

  attr_accessor :id, :name, :languages, :skills, :roles, :agent_state,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args)
    s = self
    s.id           = args[:id]
    s.name         = args[:name]
    s.languages    = args[:languages]
    s.skills       = args[:skills]
    s.roles        = args[:roles]
    s.availability = args[:availability]
    s.idle_since   = args[:idle_since]

    s.mutex        = Mutex.new
    s.agent_state  = args[:agent_state]
    s.locked       = args[:locked]
  end


  def agent_state_keyname
    "#{WimConfig.rails_env}.agent_state.#{self.id}"
  end


  def update_state_to(state)
    return unless state

    self.mutex.synchronize {
      update_internal_model(state) &&
        persist_state_with(state)
    }
  end


  def persist_state_with(state)
    $redis.set(self.agent_state_keyname, state)
    return true
  end


  def update_internal_model(new_state)
    if self.agent_state != new_state
      self.agent_state = new_state
      return true
    end
  end


  def schedule_unlock
    s = self
    s.unlock_scheduled = true

    Thread.new {
      sleep IdleTimeout

      s.locked = false if agent_state != :talking
      s.unlock_scheduled = false
      s.idle_since = Time.now.utc
    }
  end


  def unlock_necessary?
    !self.unlock_scheduled && agent_is_idle?
  end


  def agent_is_idle?
    self.locked && agent_state == :registered
  end


  def headers(agent_up)
    {
      # TODO (un)registered and talking/silent should become
      #      independent values.
      #      Also, AgentUp should be replaced by ringing/talking/silent:
      #
      'AgentState' => agent_state, 'Extension' => name,
      'AgentUp'    => agent_up
    }
  end


  def publish_to_numbers(tcid, agent_up)
    event = {
      'target_call_id' =>  tcid,
      'timestamp'      =>  Call.current_time_ms,
      'name'           => 'AgentEvent',
      'headers'        =>  headers(agent_up)
    }

    AmqpManager.numbers_publish(event)
  end


  class << self

    def update_state_for(event)
      agent = find_for(event)
      hdr   = event.headers
      atc   = agent_takes_call?(hdr)

      state = if ['5', '6'].include?(hdr['ChannelState'])
                :talking
              elsif (hdr['ChannelState'] == '0') || (event.name == 'Hangup')
                :registered
              elsif hdr['PeerStatus']
                hdr['PeerStatus'].downcase.to_sym
              end

      if agent && state && (atc || state != agent.agent_state)
        agent.update_state_to(state)
        agent.publish_to_numbers(event.target_call_id, atc)
      end
    end


    def agent_takes_call?(hdr)
      hdr['ChannelState'] == '6' && (hdr['ConnectedLineNum'] || "") != ""
    end


    def all_ids
      AgentRegistry.keys.uniq
    end


    def get_peer_from(event)
      peer = event.headers['Peer'] || event.headers['Channel']
      peer[ChannelRegex, 1] if peer
    end


    def find_for(event)
      peer = get_peer_from(event)
      (AgentRegistry.detect { |k, v| v.name == peer } || [nil, nil])[1] if peer
    end


    def checkout(agent_id, call)
      return false unless agent_id

      agent = AgentRegistry[agent_id]
      agent.locked = true
      agent
    end


    def checkin(agent_id)
      agent = AgentRegistry[agent_id]
      agent.locked = false
    end


    def where(hash)
      set_availability_scope(hash)
      keys = hash.keys

      assert (keys.map(&:to_s) - WimConfig.keys) == [], hash
      filtered_agent_ids(keys, hash)
    end


    def set_availability_scope(hash)
      hash[:locked]       =  false
      hash[:agent_state]  = :registered
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


    def update_user_setting(setter, value, uid)
      AgentRegistry[uid].send setter, (value[/,/] ? value.split(',') : value.to_sym)
      Adhearsion.logger.info "Update #{uid}'s setting: #{setter}'#{value}'"
    end


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
