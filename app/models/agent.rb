class Agent

  Registry = ThreadSafe::Cache.new
  State    = Struct.new(:languages, :skills, :roles, :availability)

  # TODO
  # Agent.where(availability: 'ready', languages: 'en').first => order FIFO/heuristic

  class << self

    def update_agent_state_with(payload)
      uid, key, value = get_key_value_pair(payload)

      if uid > 0 && key
        setter = "#{key}#{key[/y\z/] ? '' : 's'}="
        Registry[uid].send(setter, value)
        Adhearsion.logger.info "Update #{uid}'s state: #{setter}'#{value}'"
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
      raise "Received invalid message: #{payload}" if !value
    end
  end
end
