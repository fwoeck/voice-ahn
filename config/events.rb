DialEvent = Struct.new(:call_id, :from, :to, :reason)


Adhearsion::Events.draw do

  after_initialized do |event|
    User.fetch_all_agents
    Call.clear_all_redis_calls

    Thread.new { AgentCollector.start }
    Thread.new { CallScheduler.start }
  end


  stop_requested do |event|
    User.shutdown
    Adhearsion.active_calls.values.each { |call| call.hangup }
    AmqpManager.shutdown
  end


  # TODO Migrate this to punchblock events
  #
  ami name: 'BridgeExec' do |event|
    if event.headers['Response'] == 'Success'
      Call.update_state_for(event)
    end
  end


  # TODO Migrate this to punchblock events
  #
  ami name: 'Newstate' do |event|
    if ['0', '5', '6'].include?(event.headers['ChannelState'])
      Call.update_state_for(event)
      Agent.update_state_for(event)
    end
  end


  punchblock(Punchblock::Event::End) do |event|
    if (call = Adhearsion.active_calls[event.target_call_id])
      Call.set_close_state_for(event)
      Agent.finish_activity_for(call)

      if [:error, :busy].include?(event.reason)
        evt = DialEvent.new(call.id, call.from, call.to, event.reason)
        AmqpManager.dial_event(Marshal.dump evt)
      end
    end
  end
end
