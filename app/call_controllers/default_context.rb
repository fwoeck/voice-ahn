# encoding: utf-8

AGENT_MUTEX = Mutex.new

class DefaultContext < Adhearsion::CallController

  def run
    answer

    lang = choose_a_language
    Call.set_language_for(call.id, lang)

    play 'wimdu/en_how_can_we_help'

    skill = choose_a_skill
    Call.set_skill_for(call.id, skill, :queue_call)

    add_call_to_queue(lang, skill)

    hangup
  end


  def choose_a_language
    input = ask 'wimdu/en_welcome_to_wimdu', timeout: 5, limit: 1

    case input.utterance
      when '1'; 'de'
      when '2'; 'en'
      when '3'; 'es'
      when '4'; 'fr'
      when '5'; 'it'
      else 'en'
    end
  end


  def choose_a_skill
    input = nil
    while !input || !['1', '2', '3', '4'].include?(input.utterance) do
      play 'wimdu/en_sorry_i_didnt_understand' if input
      input = ask 'wimdu/en_press_two_for_booking', timeout: 5, limit: 1
    end

    case input.utterance
      when '1'; 'billing'
      when '2'; 'booking'
      when '3'; 'offers'
      when '4'; 'other'
    end
  end


  def add_call_to_queue(lang, skill)
    status = nil

    while !status || status.result != :answer do
      play 'wimdu/en_thank_you_you_will' unless status

      agent  = get_next_agent_for(lang, skill)
      status = dial "SIP/#{agent.name}", for: 15.seconds
      Agent.checkin(agent.id)
    end
  end


  def get_next_agent_for(lang, skill)
    agent = nil

    while !agent do
      sleep 1

      agent = AGENT_MUTEX.synchronize {
        agent_id = Agent.where(languages: lang, skills: skill)
                        .sort_by_idle_time.first
        Agent.checkout(agent_id)
      }
    end

    agent
  end
end
