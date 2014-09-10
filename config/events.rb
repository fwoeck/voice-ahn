Adhearsion::Events.draw do

  shutdown do |event|
    User.shutdown!
    Adhearsion.active_calls.values.each { |call| call.hangup }
    AmqpManager.shutdown!
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


  # See adhearsion-xmpp for agent availability-states
  # Has no Rayo-pendant:
  #
  # ami name: 'PeerStatus' do |event|
  #   Agent.update_registry_for(event)
  # end

  # ! This emits Rayo-Events
  #
  # punchblock(Punchblock::Event::End) do |event|
  #   puts event
  # end

  # ami name: 'Bridge' do |event|
  #   AmqpManager.publish(event)
  # end

  # ami name: 'NewCallerid' do |event|
  #   AmqpManager.publish(event)
  # end

  # ami name: 'OriginateResponse' do |event|
  #   AmqpManager.publish(event)
  # end

  # ami name: 'Newchannel' do |event|
  #   AmqpManager.publish(event)
  # end

  # ami name: 'SoftHangupRequest' do |event|
  #   AmqpManager.publish(event)
  # end
end
