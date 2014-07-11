require './app/models/agent'

class Array

  def sort_by_idle_time
    self.sort { |a1, a2|
      Agent::Registry[a1].idle_since <=> Agent::Registry[a2].idle_since
    }
  end
end
