module MenuLanguage

  def choose_a_language
    if !multiple_langs_available? || automated_test_call?
      return AhnConfig.language_menu['d']
    end

    sleep 0.5
    input = ask 'wimdu/en_choose_a_language', timeout: 5, limit: 1
    digit = (input.utterance || '0').to_i

    AhnConfig.language_menu.fetch(digit, AhnConfig.language_menu['d'])
  end


  def multiple_langs_available?
    AhnConfig.language_menu.keys.size > 1
  end
end
