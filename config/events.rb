Adhearsion::Events.draw do

  shutdown do |event|
    Adhearsion.active_calls.values.each { |call| call.hangup }

    AmqpManager.shutdown
    Celluloid.shutdown
    User.shutdown
  end


  after_initialized do |event|
    User.fetch_all_agents
    Call.clear_all_redis_calls

    Thread.new { AgentCollector.start }
    Thread.new { CallScheduler.start }
  end


  ami name: 'BridgeExec' do |event|
    if event.headers['Response'] == 'Success'
      Call.update_state_for(event)
    end
  end


  ami name: 'Newstate' do |event|
    if ['0', '5', '6'].include?(event.headers['ChannelState'])
      Call.update_state_for(event)
      Agent.update_state_for(event)
    end
  end


  ami name: 'Hangup' do |event|
    Call.close_state_for(event)
    Agent.close_state_for(event)
  end


  # Subscribe to Rayo-Events, e.g.:
  #
  # punchblock(Punchblock::Event::End) do |event|
  # end
end
