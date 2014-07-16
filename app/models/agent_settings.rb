class AgentSettings

  def initialize(args)
    @mutex            = Mutex.new

    self.id           = args[:id]
    self.name         = args[:name]
    self.languages    = args[:languages]
    self.skills       = args[:skills]
    self.roles        = args[:roles]
    self.availability = args[:availability]
    self.agent_state  = args[:agent_state]
    self.idle_since   = args[:idle_since]
    self.locked       = args[:locked]
  end

  def id
    @mutex.synchronize { @id }
  end

  def id=(other)
    @mutex.synchronize { @id = other }
  end

  def name
    @mutex.synchronize { @name }
  end

  def name=(other)
    @mutex.synchronize { @name = other }
  end

  def languages
    @mutex.synchronize { @languages }
  end

  def languages=(other)
    @mutex.synchronize { @languages = other }
  end

  def skills
    @mutex.synchronize { @skills }
  end

  def skills=(other)
    @mutex.synchronize { @skills = other }
  end

  def roles
    @mutex.synchronize { @roles }
  end

  def roles=(other)
    @mutex.synchronize { @roles = other }
  end

  def availability
    @mutex.synchronize { @availability }
  end

  def availability=(other)
    @mutex.synchronize { @availability = other }
  end

  def agent_state
    @mutex.synchronize { @agent_state }
  end

  def agent_state=(other)
    @mutex.synchronize { @agent_state = other }
  end

  def idle_since
    @mutex.synchronize { @idle_since }
  end

  def idle_since=(other)
    @mutex.synchronize { @idle_since = other }
  end

  def locked
    @mutex.synchronize { @locked }
  end

  def locked=(other)
    @mutex.synchronize { @locked = other }
  end
end
