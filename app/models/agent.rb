class Agent

  Registry = ThreadSafe::Cache.new
  State    = Struct.new(:languages, :skills, :roles, :availability)

  # TODO
  # Agent.where(availability: 'ready', languages: 'en').first => order FIFO/heuristic

end
