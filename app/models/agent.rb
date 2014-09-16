require './app/models/keynames'

AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP\/(\d\d\d\d?)/
IdleTimeout   = 3


class Agent
  include Keynames

  attr_accessor :id, :name, :languages, :skills, :activity, :visibility, :call_id,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args=nil)
    tap { |s|
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
    } if args
  end


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
    if vis == :online
      Redis.current.sadd(online_users_keyname, id)
    else
      Redis.current.srem(online_users_keyname, id)
    end
  end


  def persist_activity_with(act)
    Redis.current.set(activity_keyname, act, {ex: 1.week})
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


  def handle_update
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
      agent.update_activity_to(act) && agent.publish_update(tcid)
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


    def assert(value, data)
      raise "Received invalid options: #{data}" if !value
    end
  end
end
