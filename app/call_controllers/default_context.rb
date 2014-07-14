require 'thread'

QueueStruct = Struct.new(:queue, :lang, :skill, :queued_at, :answered)


class DefaultContext < Adhearsion::CallController

  after_call :clear_agent


  def run
    answer
    play 'wimdu/en_welcome_to_wimdu'

    lang = choose_a_language
    Call.set_language_for(call.id, lang)

    play "wimdu/#{lang}_thank_you"
    play "wimdu/#{lang}_how_can_we_help_you"

    skill = choose_a_skill(lang)
    Call.set_skill_for(call.id, skill)

    Call.set_queued_at(call.id)
    queue_and_handle_call(lang, skill)

    remove_call_from_queue
    hangup
  end


  def get_queue_struct_for(lang, skill)
    Call::Queues[call.id] ||= QueueStruct.new(
      Queue.new, lang, skill, Time.now.utc, false
    )
  end


  def remove_call_from_queue
    Call::Queues.delete call.id
  end


  def choose_a_language
    input = ask 'wimdu/en_choose_a_language', timeout: 5, limit: 1

    case input.utterance
      when '1'; 'de'
      when '2'; 'en'
      when '3'; 'es'
      when '4'; 'fr'
      when '5'; 'it'
      else 'en'
    end
  end


  def choose_a_skill(lang)
    input = nil
    while !input || !['1', '2', '3', '4'].include?(input.utterance) do
      play "wimdu/#{lang}_i_didnt_understand" if input
      input = ask "wimdu/#{lang}_choose_a_skill", timeout: 5, limit: 1
    end

    case input.utterance
      when '1'; 'new_booking'
      when '2'; 'ext_booking'
      when '3'; 'payment'
      when '4'; 'other'
    end
  end


  def queue_and_handle_call(lang, skill)
    qstruct = get_queue_struct_for(lang, skill)
    status  = nil

    while !status || status.result != :answer do
      play "wimdu/#{lang}_you_will_be_connected" unless status

      begin
        @agent = wait_for_next_agent_on(qstruct)
        status = dial "SIP/#{@agent.name}", for: 15.seconds
      ensure
        clear_agent
      end
    end
  end


  def clear_agent
    checkin_agent(@agent)
    @agent = nil
  end


  def checkin_agent(agent)
    if agent
      Thread.new {
        sleep 5
        Agent.checkin(agent.id)
      }
    end
  end


  def wait_for_next_agent_on(qstruct)
    qstruct.answered = false
    agent = qstruct.queue.pop
    qstruct.answered = true

    agent
  end
end
