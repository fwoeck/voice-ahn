# encoding: utf-8

Adhearsion::Events.draw do

  # punchblock do |event|
  #   puts event
  # end

  ami name: 'Bridge' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'BridgeExec' do |event|
    AmqpManager.numbers_publish(event)
  end


  ami name: 'PeerStatus' do |event|
    peer  = event.headers['Peer'][/SIP.(.+)$/,1]
    agent = Agent.find_agent_for(peer)

    if agent && agent.callstate != 'talking'
      status = event.headers['PeerStatus'].downcase
      Agent.setup_current_callstate_for(agent, status)
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
      peer  = event.headers['CallerIDNum'][/\d+/]
      agent = Agent.find_agent_for(peer)

      Agent.setup_current_callstate_for(agent, 'talking')
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
    peer  = event.headers['CallerIDNum'][/\d+/]
    agent = Agent.find_agent_for(peer)

    Agent.setup_current_callstate_for(agent, 'registered')
    AmqpManager.numbers_publish(event)
  end
end
