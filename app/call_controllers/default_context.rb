require 'thread'
require 'timeout'


QueueStruct = Struct.new(
  :queue, :lang, :skill, :queued_at,
  :answered, :tries, :status, :agent
)


class DefaultContext < Adhearsion::CallController

  after_call :remove_call_from_queue


  def run
    answer
    play 'wimdu/en_welcome_to_wimdu'

    lang = choose_a_language
    Call.set_language_for(call_id, lang)

    sleep 1
    play "wimdu/#{lang}_how_can_we_help_you"

    skill = choose_a_skill(lang)
    Call.set_skill_for(call_id, skill)

    Call.set_queued_at(call_id)
    queue_and_handle_call(lang, skill)

    hangup
  end


  def call_id
    @call_id ||= call.id
  end


  def get_queue_struct_for(lang, skill)
    Call::Queues[call_id] ||= QueueStruct.new(
      Queue.new, lang, skill, Time.now.utc, false, 0, nil, nil
    )
  end


  def remove_call_from_queue
    Call::Queues.delete call_id
    @call_id = nil
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
    tries = 0

    while tries < 3 && !user_entered_skill?(tries, input) do
      play "wimdu/#{lang}_i_didnt_understand" if input

      input  = ask "wimdu/#{lang}_choose_a_skill", timeout: 5, limit: 1
      tries += 1
    end

    case input.utterance
      when '1'; 'new_booking'
      when '2'; 'ext_booking'
      when '3'; 'payment'
      when '4'; 'other'
      else 'other'
    end
  end


  def user_entered_skill?(tries, input)
    input && ['1', '2', '3', '4'].include?(input.utterance)
  end


  def dial_timeout
    call.from[/SIP.100/] ? 5 : 15
  end


  def queue_and_handle_call(lang, skill)
    qs = get_queue_struct_for(lang, skill)

    while !call_was_answered_or_timed_out?(qs) do
      play "wimdu/#{lang}_you_will_be_connected" unless qs.status

      begin
        wait_for_next_agent_on(qs)
        qs.status = dial "SIP/#{qs.agent.name}", for: dial_timeout.seconds
        checkin_agent(qs)
      rescue TimeoutError
        qs.status = :timeout
        checkin_agent(qs)
      end
    end
  end


  def checkin_agent(qs)
    Agent.update_state_for(qs.agent, 'registered')
    qs.agent    = nil
    qs.answered = false
  end


  def call_was_answered_or_timed_out?(qs)
    return false unless qs.status
    qs.status == :timeout || qs.status.result == :answer
  end


  def wait_for_next_agent_on(qs)
    raise TimeoutError if qs.tries > 2

    qs.tries += 1
    qs.agent  = nil
    timeout   = 2 * dial_timeout

    Timeout::timeout(timeout) {
      qs.agent = qs.queue.pop
    }
  end
end
