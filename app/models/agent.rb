class Agent

  Registry = ThreadSafe::Cache.new
  State    = Struct.new(:languages, :skills, :roles, :availability)

  # TODO
  # Agent.where(availability: 'ready', languages: 'en').first => order FIFO/heuristic


  def self.update_agent_state_with(payload)
    data  = JSON.parse payload
    uid   = data.delete('user_id').to_i
    key   = data.keys.first
    value = data[key]

    if uid > 0 && key
      setter = "#{key}#{key[/y\z/] ? '' : 's'}="
      Registry[uid].send(setter, value)
      puts ">>> Update #{uid} status: #{setter}'#{value}'"
    end
  end
end
