module MenuSkill

  def choose_a_skill(lang)
    if !multiple_skills_available? || automated_test_call?
      return AhnConfig.skill_menu['d']
    end

    sleep 0.5
    play "wimdu/#{lang}_how_can_we_help_you"

    skill = gather_skill_choice(lang)

    sleep 0.5
    play "wimdu/#{lang}_thank_you"
    skill
  end


  def multiple_skills_available?
    AhnConfig.skill_menu.keys.size > 1
  end


  def gather_skill_choice(lang)
    input = nil
    tries = 0

    while tries < 3 && !user_entered_skill?(tries, input) do
      play "wimdu/#{lang}_i_didnt_understand" if input

      input  = ask "wimdu/#{lang}_choose_a_skill", timeout: 5, limit: 1
      tries += 1
    end

    digit = (input.utterance || '0').to_i
    AhnConfig.skill_menu.fetch(digit, AhnConfig.skill_menu['d'])
  end


  def user_entered_skill?(tries, input)
    keys = AhnConfig.skill_menu.keys.map(&:to_s)
    input && keys.include?(input.utterance)
  end
end
