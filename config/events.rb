Adhearsion::Events.draw do


  shutdown do |event|
    Adhearsion.active_calls.values.each { |call| call.hangup }
    AmqpManager.shutdown
  end


  after_initialized do |event|
    Call.clear_all_redis_calls
  end


  ami name: 'BridgeExec' do |event|
    if event.headers['Response'] == 'Success'
      Call.update_state_for(event)
    end

    AmqpManager.numbers_publish(event)
  end


  ami name: 'PeerStatus' do |event|
    agent     = Agent.find_for(event)
    new_state = event.headers['PeerStatus'].downcase

    if agent
      # agent.mutex.synchronize {
        old_state = agent.agent_state

        if old_state != 'talking'
          Agent.update_state_for(agent, new_state) &&
            AmqpManager.numbers_publish(event)
        end
      # }
    end
  end


  ami name: 'Newstate' do |event|
    agent_state = nil

    if ['4', '5', '6'].include?(event.headers['ChannelState'])
      Call.update_state_for(event)
      agent_state = 'talking'
    elsif event.headers['ChannelState'] == '0'
      agent_state = 'registered'
    end

    if agent_state && (agent = Agent.find_for event)
      Agent.update_state_for(agent, agent_state) &&
        AmqpManager.numbers_publish(event)
    end
  end


  ami name: 'Hangup' do |event|
    Call.close_state_for(event)

    if (agent = Agent.find_for event)
      Agent.update_state_for(agent, 'registered') &&
        AmqpManager.numbers_publish(event)
    end
  end


  # punchblock do |event|
  #   puts event
  # end

  # ami name: 'Bridge' do |event|
  #   AmqpManager.numbers_publish(event)
  # end

  # ami name: 'NewCallerid' do |event|
  #   AmqpManager.numbers_publish(event)
  # end

  # ami name: 'OriginateResponse' do |event|
  #   AmqpManager.numbers_publish(event)
  # end

  # ami name: 'Newchannel' do |event|
  #   AmqpManager.numbers_publish(event)
  # end

  # ami name: 'SoftHangupRequest' do |event|
  #   AmqpManager.numbers_publish(event)
  # end
end
