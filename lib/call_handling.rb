module CallHandling

  def queue_and_handle_call(lang, skill)
    @qs = get_queue_struct_for(lang, skill)

    while qs && !call_was_answered_or_timed_out? do
      qs.dispatched = false
      qs.agent      = nil
      dial_to_next_agent
    end
  end


  def get_queue_struct_for(lang, skill)
    Call::Queues[call_id] ||= QueueStruct.new(
      Queue.new, lang, skill, Time.now.utc,
      false, 0, nil, nil, nil, call_id
    )
  end


  def call_was_answered_or_timed_out?
    return false unless qs.status
    qs.status == :timeout || qs.status.result == :answer
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


  # FIXME This sets the originId & choices on the agent's
  #       call leg to provide these details to the services
  #       downstream.
  #       It depends on cd.status.calls.first, which
  #       seems brittle.
  #
  def update_agent_leg(cd, qs)
    tcid = cd.status.calls.first.id
    Call.set_params_for(tcid, qs)
  end
end
