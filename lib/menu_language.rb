module MenuLanguage

  def choose_a_language
    return AhnConfig.language_menu['d'] unless multiple_langs_available?

    sleep 0.5
    input = ask 'wimdu/en_choose_a_language', timeout: 5, limit: 1
    digit = (input.utterance || '0').to_i

    AhnConfig.language_menu.fetch(digit, AhnConfig.language_menu['d'])
  end


  def multiple_langs_available?
    AhnConfig.language_menu.keys.size > 1
  end
end
