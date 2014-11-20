require './lib/agent_updates'
require './lib/agent_helpers'
require './lib/agent_locking'
require './lib/agent_rpc'
require './lib/keynames'

AgentRegistry = ThreadSafe::Hash.new
ChannelRegex  = /SIP\/(\d\d\d\d?)/
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
      agent = get_by_name(get_peer_from event)
      chan  = event.headers['ChannelState']

      update_activity_for(
        agent, activity_name(chan), event.target_call_id
      )
    end


    def activity_name(chan)
      case chan
        when '5' then :ringing
        when '6' then :talking
        else :silent
      end
    end


    def update_activity_for(agent, act, tcid)
      return unless agent
      agent.update_activity_to(act) && agent.publish_update(tcid)
    end


    def finish_activity_for(call)
      agent = extract_from(call)
      update_activity_for(agent, :silent, call.id)
    end


    def all_ids
      AgentRegistry.keys
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
