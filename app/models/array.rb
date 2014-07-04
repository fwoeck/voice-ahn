class Array

  def sort_by_idle_time
    self.sort { |a1, a2|
      Registry[a1].idle_since <=> Registry[a2].idle_since
    }
  end
end
