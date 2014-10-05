module UserFields

  def availability
    @memo_availability ||= (
      RPool.with { |con|
        con.get(availability_keyname)
      } || availability_default
    )
  end


  def activity
    @memo_activity ||= (
      RPool.with { |con|
        con.get(activity_keyname)
      } || activity_default
    )
  end


  def visibility
    @memo_visibility ||= (
      RPool.with { |con|
        con.sismember(online_users_keyname, id)
      } ? :online : :offline
    )
  end


  def skills
    @memo_skills ||= RPool.with { |con|
      con.smembers(skills_keyname)
    }.sort
  end


  def languages
    @memo_languages ||= RPool.with { |con|
      con.smembers(languages_keyname)
    }.sort
  end
end
