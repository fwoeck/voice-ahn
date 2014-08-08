AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP\/(\d+)/
IdleTimeout   = 3


class Agent

  attr_accessor :id, :name, :languages, :skills, :roles, :agent_state, :agent_reg,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args)
    s = self
    s.id           = args[:id]
    s.name         = args[:name]
    s.roles        = args[:roles]
    s.skills       = args[:skills]
    s.languages    = args[:languages]
    s.idle_since   = args[:idle_since]
    s.availability = args[:availability]
    s.agent_state  = args[:agent_state]
    s.agent_reg    = args[:agent_reg]
    s.locked       = args[:locked]
    s.mutex        = Mutex.new
  end


  def agent_state_keyname
    "#{WimConfig.rails_env}.agent_state.#{self.id}"
  end


  def agent_reg_keyname
    "#{WimConfig.rails_env}.agent_reg.#{self.id}"
  end


  def update_registry_to(reg)
    return if !reg || reg == agent_reg

    self.mutex.synchronize {
      update_internal_reg(reg) && persist_reg_with(reg)
    }
  end


  def update_state_to(state)
    return if !state || state == agent_state

    self.mutex.synchronize {
      update_internal_state(state) && persist_state_with(state)
    }
  end


  def persist_reg_with(reg)
    $redis.set(self.agent_reg_keyname, reg)
    return true
  end


  def persist_state_with(state)
    $redis.set(self.agent_state_keyname, state)
    return true
  end


  def update_internal_reg(new_reg)
    if self.agent_reg != new_reg
      self.agent_reg = new_reg
      return true
    end
  end


  def update_internal_state(new_state)
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

      s.locked = false if agent_state == :silent
      s.unlock_scheduled = false
      s.idle_since = Time.now.utc
    }
  end


  def unlock_necessary?
    self.locked && !self.unlock_scheduled && agent_is_idle?
  end


  def agent_is_idle?
    self.agent_state == :silent
  end


  def headers
    {
      'AgentState' => agent_state, 'Extension' => name, 'AgentReg' => agent_reg
    }
  end


  def publish_to_numbers(tcid)
    event = {
      'target_call_id' =>  tcid,
      'timestamp'      =>  Call.current_time_ms,
      'name'           => 'AgentEvent',
      'headers'        =>  headers
    }

    AmqpManager.numbers_publish(event)
  end


  class << self

    def update_registry_for(event)
      agent = find_for(event)
      hdr   = event.headers
      reg   = hdr['PeerStatus'].downcase.to_sym

      if agent
        agent.update_registry_to(reg) &&
          agent.publish_to_numbers(event.target_call_id)
      end
    end


    def update_state_for(event)
      agent = find_for(event)
      hdr   = event.headers
      chan  = hdr['ChannelState']

      state = if    chan == '5'
                :ringing
              elsif chan == '6'
                :talking
              elsif chan == '0' || event.name == 'Hangup'
                :silent
              end

      if agent
        agent.update_state_to(state) &&
          agent.publish_to_numbers(event.target_call_id)
      end
    end


    # def agent_takes_call?(hdr)
    #   hdr['ChannelState'] == '6' && (hdr['ConnectedLineNum'] || "") != ""
    # end


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
      hash[:agent_reg]    = :registered
      hash[:agent_state]  = :silent
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
