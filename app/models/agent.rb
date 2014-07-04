class Agent

  Registry = ThreadSafe::Cache.new
  State    = Struct.new(:languages, :skills, :roles, :availability)

  # TODO
  # Agent.where(availability: 'ready', languages: 'en').first => order FIFO/heuristic

  class << self
    def update_agent_state_with(payload)
      uid, key, value = parse_payload(payload)

      if uid > 0 && key
        setter = "#{key}#{key[/y\z/] ? '' : 's'}="
        Registry[uid].send(setter, value)
        Adhearsion.logger.info "Update #{uid}'s state: #{setter}'#{value}'"
      end
    end

    def parse_payload(payload)
      data  = JSON.parse(payload)
      assert data.keys.include?('user_id')
      assert data.keys.count == 2

      uid   = data.delete('user_id').to_i
      key   = data.keys.first
      value = data[key]

      [uid, key, value]
    end

    def assert(value)
      raise "An assertion failed!" unless !!value
    end
  end
end
