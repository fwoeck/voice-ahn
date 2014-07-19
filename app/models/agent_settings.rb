class AgentSettings

  attr_accessor :id, :name, :languages, :skills, :roles, :agent_state,
                :locked, :availability, :idle_since, :mutex, :unlock_scheduled


  def initialize(args)
    self.id           = args[:id]
    self.name         = args[:name]
    self.languages    = args[:languages]
    self.skills       = args[:skills]
    self.roles        = args[:roles]
    self.availability = args[:availability]
    self.idle_since   = args[:idle_since]

    self.mutex        = Mutex.new
    self.agent_state  = args[:agent_state]
    self.locked       = args[:locked]
  end
end
