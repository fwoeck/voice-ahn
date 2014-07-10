# encoding: utf-8

class DefaultContext < Adhearsion::CallController

  def run
    answer

    # Choose a language
    #
    input = ask 'wimdu/en_welcome_to_wimdu', timeout: 5, limit: 1
    lang  = case input.utterance
    when '1'
      'de'
    when '2'
      'en'
    when '3'
      'es'
    when '4'
      'fr'
    when '5'
      'it'
    else
      'en'
    end

    Call.set_language_for(call.id, lang)
    play 'wimdu/en_how_can_we_help'

    # Choose a skill
    #
    input = nil
    while !input || !['1', '2', '3', '4'].include?(input.utterance) do
      play 'wimdu/en_sorry_i_didnt_understand' if input
      input = ask 'wimdu/en_press_two_for_booking', timeout: 5, limit: 1
    end

    skill = case input.utterance
    when '1'
      'billing'
    when '2'
      'booking'
    when '3'
      'offers'
    when '4'
      'other'
    end

    Call.set_skill_for(call.id, skill, :queue_call)

    status = nil
    while !status || status.result != :answer do
      play 'wimdu/en_thank_you_you_will' unless status

      # Be queued
      #
      agent_id = nil
      while !agent_id do
        sleep 1
        agent_id = Agent.where(
          languages: lang,
          skills:    skill
        ).sort_by_idle_time.first
      end
      agent = Agent::Registry[agent_id]

      # Be dispatched
      # TODO set dispatched_at timestamp
      #
      status = dial "SIP/#{agent.name}", for: 15.seconds
    end

    hangup
  end
end
