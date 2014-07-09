Adhearsion::Events.draw do

  # punchblock do |event|
  #   puts event
  # end

  ami name: 'Bridge' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'BridgeExec' do |event|
    if event.headers['Response'] == 'Success'
      Call.update_state_for(event)
    end

    AmqpManager.numbers_publish(event)
  end


  ami name: 'PeerStatus' do |event|
    agent = Agent.find_for(event)

    if agent && agent.agent_state != 'talking'
      status = event.headers['PeerStatus'].downcase
      Agent.setup_current_state_for(agent, status)
    end

    AmqpManager.numbers_publish(event)
  end


  ami name: 'NewCallerid' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'OriginateResponse' do |event|
    AmqpManager.numbers_publish(event)
  end


  ami name: 'Newstate' do |event|
    if event.headers['ChannelState'] == '6' # 6 => Up
      agent = Agent.find_for(event)

      Call.setup_new_state_for(event)
      Agent.setup_current_state_for(agent, 'talking')
    end

    AmqpManager.numbers_publish(event)
  end


  ami name: 'Newchannel' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'SoftHangupRequest' do |event|
    AmqpManager.numbers_publish(event)
  end


  ami name: 'Hangup' do |event|
    Call.close_state_for(event)

    agent = Agent.find_for(event)
    Agent.setup_current_state_for(agent, 'registered')

    AmqpManager.numbers_publish(event)
  end
end
