require './app/models/keynames'

AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP\/(\d\d\d\d?)/
IdleTimeout   = 3


class Agent
  include Keynames

  attr_accessor :id, :name, :languages, :skills, :activity, :visibility,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args)
    s = self
    s.id           = args[:id]
    s.name         = args[:name]
    s.skills       = args[:skills]
    s.languages    = args[:languages]
    s.idle_since   = args[:idle_since]
    s.availability = args[:availability]
    s.visibility   = args[:visibility]
    s.activity     = args[:activity]
    s.locked       = args[:locked]
    s.mutex        = Mutex.new
  end


  # FIXME This fails if an array field-name ends with a "y":
  #
  def key_contains_array?(key)
    !key[/y$/]
  end


  def interpolate_setter_from(key)
    "#{key}#{key_contains_array?(key) ? 's' : ''}="
  end


  def update_settings_to(key, value)
    setter = interpolate_setter_from(key)
    self.send setter, (
      key_contains_array?(key) ? value.split(',') : value.to_sym
    )

    if key == :visibility
      persist_visibility_with(value)
      publish
    end
    Adhearsion.logger.info "Update #{id}'s setting: #{setter}'#{value}'"
  end


  def update_activity_to(act)
    return if !act || act == activity

    self.mutex.synchronize {
      update_internal_activity(act) && persist_activity_with(act)
    }
  end


  def persist_visibility_with(vis)
    if vis == :online
      Redis.current.sadd(online_users_keyname, id)
    else
      Redis.current.srem(online_users_keyname, id)
    end
  end


  def persist_activity_with(act)
    Redis.current.set(activity_keyname, act, ex: 1.week)
    return true
  end


  def update_internal_activity(new_act)
    if self.activity != new_act
      self.activity = new_act
      return true
    end
  end


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


  def headers
    { activity:   activity,
      visibility: visibility,
      extension:  name
    }
  end


  def publish(tcid=nil)
    event = {
      target_call_id: tcid,
      timestamp:      Call.current_time_ms,
      name:          'AgentEvent',
      headers:        headers
    }

    AmqpManager.publish_agent(event)
  end


  class << self

    def update_state_for(event)
      agent = find_for(event)
      hdr   = event.headers
      chan  = hdr['ChannelState']

      act = case chan
              when '5' then :ringing
              when '6' then :talking
              else :silent
            end

      update_activity_for(agent, act, event.target_call_id)
    end


    def update_activity_for(agent, act, tcid)
      return unless agent
      agent.update_activity_to(act) && agent.publish(tcid)
    end


    def close_state_for(event)
      agent = find_for(event)
      update_activity_for(agent, :silent, event.target_call_id)
    end


    def all_ids
      AgentRegistry.keys
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


    def where(hash)
      set_availability_scope(hash)
      keys = hash.keys

      assert (keys.map(&:to_s) - AhnConfig.keys) == [], hash
      filtered_agent_ids(keys, hash)
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


    def update_client_settings_with(data)
      uid, key, value = get_agent_value_pair(data)
      agent = AgentRegistry[uid]

      if agent && key
        agent.update_settings_to(key, value)
      else
        synch_agent_from_db(agent, uid)
      end
    end


    def synch_agent_from_db(agent, uid)
      name = nil

      if (db_user = User[uid])
        name = db_user.name
        db_user.build_agent
      elsif agent
        name = agent.name
        AgentRegistry.delete uid
      end

      reload_asterisk_sip_peer(name)
    end


    def reload_asterisk_sip_peer(name)
      return unless name
      system("sudo asterisk -rx 'sip prune realtime #{name}'")
    end


    def get_agent_value_pair(data)
      uid = data.delete(:user_id).to_i
      key = data.keys.first

      [uid, key, data[key]]
    end


    def assert(value, data)
      raise "Received invalid options: #{data}" if !value
    end
  end
end
