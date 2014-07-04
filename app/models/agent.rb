module Agents

  Registry = ThreadSafe::Cache.new
  State    = Struct.new(:languages, :skills, :roles, :availability, :idle_since)

  class << self

    # Agents.where(availability: :idle, languages: :en).first
    #
    def where(hash)
      keys = hash.keys
      assert (keys.map(&:to_s) - WimConfig.keys) == [], hash
      sort_by_idle_time filtered_agent_ids(keys, hash, fetch_all_agent_ids)
    end


    def sort_by_idle_time(agent_ids)
      agent_ids.sort { |a1, a2|
        Registry[a1].idle_since <=> Registry[a2].idle_since
      }
    end


    def filtered_agent_ids(keys, hash, agent_ids)
      keys.each do |key|
        agent_ids = agent_ids.select { |id|
          current_key_matches?(hash, key, id)
        }
      end
      agent_ids
    end


    def current_key_matches?(hash, key, id)
      value   = Registry[id].send(key)
      request = hash[key].to_s

      value.is_a?(Array) ?
        value.include?(request) :
        value == request
    end


    def fetch_all_agent_ids
      User.select(:id).all.map(&:id)
    end


    def update_agent_state_with(payload)
      uid, key, value = get_key_value_pair(payload)

      if uid > 0 && key
        setter = "#{key}#{key[/y\z/] ? '' : 's'}="
        update_idle_since(key, value, uid)
        update_status_field(setter, value, uid)
      end
    end


    def update_status_field(setter, value, uid)
      Registry[uid].send(setter, value)
      Adhearsion.logger.info "Update #{uid}'s state: #{setter}'#{value}'"
    end


    def update_idle_since(key, value, uid)
      if key == 'availability' && value == 'idle'
        Registry[uid].idle_since = Time.now.utc
      end
    end


    def get_key_value_pair(payload)
      data  = parsed_json(payload)
      uid   = data.delete('user_id').to_i
      key   = data.keys.first
      value = data[key]

      [uid, key, value]
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
