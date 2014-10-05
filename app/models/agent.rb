require './lib/agent_updates'
require './lib/agent_helpers'
require './lib/agent_locking'
require './lib/agent_rpc'
require './lib/keynames'

AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /^SIP\/(\d\d\d\d?)/
IdleTimeout   = 3


class Agent
  extend  AgentHelpers
  include AgentUpdates
  include AgentLocking
  include AgentRpc
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
  end
end
