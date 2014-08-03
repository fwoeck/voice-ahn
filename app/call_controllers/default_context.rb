require 'thread'
require 'timeout'


QueueStruct = Struct.new(
  :queue, :lang, :skill, :queued_at, :dispatched,
  :tries, :status, :agent, :moh
)


class DefaultContext < Adhearsion::CallController

  attr_accessor :qs


  def run
    answer
    call.on_end { cleanup_leftovers }
    play 'wimdu/en_welcome_to_wimdu'

    lang = choose_a_language
    Call.set_language_for(call_id, lang)

    sleep 1
    play "wimdu/#{lang}_how_can_we_help_you"

    skill = choose_a_skill(lang)
    Call.set_skill_for(call_id, skill)

    play "wimdu/#{lang}_you_will_be_connected"

    Call.set_queued_at(call_id)
    queue_and_handle_call(lang, skill)
  end


  def call_id
    @call_id ||= call.id
  end


  def get_queue_struct_for(lang, skill)
    Call::Queues[call_id] ||= QueueStruct.new(
      Queue.new, lang, skill, Time.now.utc,
      false, 0, nil, nil, nil
    )
  end


  def cleanup_leftovers
    Call::Queues.delete call_id
    @call_id = @qs = nil
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
    self.qs = get_queue_struct_for(lang, skill)

    while qs && !call_was_answered_or_timed_out? do
      qs.dispatched = false
      qs.agent      = nil
      dial_to_next_agent
    end
  end


  def dial_to_next_agent
    wait_for_next_agent_on
    qs.status = dial_to qs.agent.name, for: dial_timeout.seconds
  rescue TimeoutError, NoMethodError
     record_voice_memo
  end


  def record_voice_memo
    return unless qs
    qs.status = :timeout

    stop_moh
    play "wimdu/#{qs.lang}_leave_a_message"

    result = record start_beep: true, max_duration: 60_000
    postprocess_recording result.recording_uri
  end


  def postprocess_recording(uri)
    rid = uri[/[0-9a-f-]{10,}/]

    Call.set_mailbox(call_id, rid)
    Thread.new {
      system "sox --norm=-1 #{WimConfig.mp3_source}/#{rid}.wav -C 128.2 #{WimConfig.mp3_target}/#{rid}.mp3"
    }
  end


  def dial_to(to, options)
    cd = Adhearsion::CallController::Dial::Dial.new("SIP/#{to}", options, call)
    metadata['current_dial'] = cd
    execute_dial(cd)
  end


  def stop_moh
    if qs && qs.moh
      begin
        qs.moh.stop!
      rescue Punchblock::Component::InvalidActionError
      end
      qs.moh = nil
    end
  end


  def execute_dial(cd)
    cd.run self
    stop_moh
    cd.await_completion
    cd.cleanup_calls

    return cd.status
  end


  def call_was_answered_or_timed_out?
    return false unless qs.status
    qs.status == :timeout || qs.status.result == :answer
  end


  def wait_for_next_agent_on
    raise TimeoutError if qs.tries > 2
    qs.tries += 1
    timeout   = 2 * dial_timeout

    Timeout::timeout(timeout) {
      stop_moh
      qs.moh = play! 'wimdu/songbirds'
      qs.agent = qs.queue.pop
    }
  end
end
