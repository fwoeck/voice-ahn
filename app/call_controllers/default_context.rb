# encoding: utf-8

class DefaultContext < Adhearsion::CallController

  def run
    answer

    # choose language
    #
    input = ask 'wimdu/en_welcome_to_wimdu', timeout: 5, limit: 1
    # play 'wimdu/en_sorry_no_foreign_language' if input.utterance == '1'

    play 'wimdu/en_how_can_we_help'

    input = ask 'wimdu/en_press_two_for_booking', timeout: 5, limit: 1
    while !['2', '3'].include?(input.utterance) do
      play 'wimdu/en_sorry_i_didnt_understand'
      input = ask 'wimdu/en_press_two_for_booking', timeout: 5, limit: 1
    end

    play 'wimdu/en_thank_you_you_will'
    operator = (input.utterance == '2' ? 'SIP/102' : 'SIP/103')
    status   = dial operator, for: 15.seconds

    while status.result != :answer do
      play 'wimdu/en_thank_you_you_will'
      status = dial operator, for: 15.seconds
    end

    hangup
  end
end
