require 'thread'
require 'timeout'


QueueStruct = Struct.new(
  :queue, :language, :skill, :queued_at, :dispatched,
  :tries, :status, :agent, :moh, :call_id
)


class DefaultContext < Adhearsion::CallController

  attr_accessor :qs


  def run
    answer
    call.on_end { cleanup_leftovers }

    sleep 0.5
    play 'wimdu/en_welcome_to_wimdu'

    lang = choose_a_language
    Call.set_language_for(call_id, lang)

    skill = choose_a_skill(lang)
    Call.set_skill_for(call_id, skill)

    sleep 0.5
    play "wimdu/#{lang}_you_will_be_connected"

    Call.set_queued_at(call_id)
    queue_and_handle_call(lang, skill)
  end


  def call_id
    @call_id ||= call.id
  end


  def cleanup_leftovers
    Call::Queues.delete call_id
    @call_id = @qs = nil
  end


  def multiple_langs_available?
    AhnConfig.language_menu.keys.size > 1
  end


  def multiple_skills_available?
    AhnConfig.skill_menu.keys.size > 1
  end


  def choose_a_language
    return AhnConfig.language_menu['d'] unless multiple_langs_available?

    sleep 0.5
    input = ask 'wimdu/en_choose_a_language', timeout: 5, limit: 1
    digit = (input.utterance || '0').to_i

    AhnConfig.language_menu.fetch(digit, AhnConfig.language_menu['d'])
  end


  def choose_a_skill(lang)
    return AhnConfig.skill_menu['d'] unless multiple_skills_available?

    sleep 0.5
    play "wimdu/#{lang}_how_can_we_help_you"

    skill = gather_skill_choice(lang)

    sleep 0.5
    play "wimdu/#{lang}_thank_you"
    skill
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


  def get_queue_struct_for(lang, skill)
    Call::Queues[call_id] ||= QueueStruct.new(
      Queue.new, lang, skill, Time.now.utc,
      false, 0, nil, nil, nil, call_id
    )
  end


  def queue_and_handle_call(lang, skill)
    @qs = get_queue_struct_for(lang, skill)

    while qs && !call_was_answered_or_timed_out? do
      qs.dispatched = false
      qs.agent      = nil
      dial_to_next_agent
    end
  end


  def dial_to_next_agent
    wait_for_next_agent
    qs.status = dial_to(qs, for: DialTimeout.seconds)
  rescue TimeoutError, NoMethodError
    record_voice_memo
  end


  def wait_for_next_agent
    raise TimeoutError if qs.tries > 2
    qs.tries += 1
    timeout   = 2 * DialTimeout

    Timeout::timeout(timeout) {
      stop_moh
      qs.moh = play! 'wimdu/songbirds'
      qs.agent = qs.queue.pop
    }
  end


  def dial_to(qs, options)
    to = qs.agent.name
    cd = Adhearsion::CallController::Dial::Dial.new("SIP/#{to}", options, call)
    metadata['current_dial'] = cd
    execute_dial(cd, qs)
  end


  def execute_dial(cd, qs)
    stop_moh
    cd.run(self)
    update_agent_leg(cd, qs)
    cd.await_completion
    cd.cleanup_calls

    return cd.status
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


  def update_agent_leg(cd, qs)
    tcid = cd.status.calls.first.id
    Call.set_params_for(tcid, qs)
  end


  def record_voice_memo
    qs.status = :timeout
    Call.set_dispatched_at(call_id)

    stop_moh
    play "wimdu/#{qs.language}_leave_a_message"

    result = record start_beep: true, max_duration: 60_000
    postprocess_recording result.recording_uri
  rescue
    # Usually happens, because qs has been removed.
  end


  def postprocess_recording(uri)
    rid = uri[/[0-9a-f-]{10,}/]

    Call.set_mailbox(call_id, rid)
    Thread.new {
      system "sox --norm=-1 #{AhnConfig.mp3_source}/#{rid}.wav -C 128.2 #{AhnConfig.mp3_target}/#{rid}.mp3"
    }
  end


  def call_was_answered_or_timed_out?
    return false unless qs.status
    qs.status == :timeout || qs.status.result == :answer
  end
end
