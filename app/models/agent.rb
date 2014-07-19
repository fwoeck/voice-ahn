AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP.(\d+)/
IdleTimeout   = 3


class Agent

  attr_accessor :id, :name, :languages, :skills, :roles, :agent_state,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args)
    self.id           = args[:id]
    self.name         = args[:name]
    self.languages    = args[:languages]
    self.skills       = args[:skills]
    self.roles        = args[:roles]
    self.availability = args[:availability]
    self.idle_since   = args[:idle_since]

    self.mutex        = Mutex.new
    self.agent_state  = args[:agent_state]
    self.locked       = args[:locked]
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
    Thread.new {
      self.unlock_scheduled = true
      sleep IdleTimeout

      self.locked = false
      self.unlock_scheduled = false
      self.idle_since = Time.now.utc
    }
  end


  def unlock_necessary?
    !self.unlock_scheduled && agent_is_idle?
  end


  def agent_is_idle?
    self.locked && self.agent_state == :registered
  end


  class << self


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
