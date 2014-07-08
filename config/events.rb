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
    peer   = event.headers['Peer'][/SIP.(.+)$/,1]
    status = event.headers['PeerStatus'].downcase
    Agent.setup_current_callstate_for(peer, status)

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
      peer = event.headers['CallerIDNum'][/\d+/]
      Agent.setup_current_callstate_for(peer, 'talking')
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
    peer = event.headers['CallerIDNum'][/\d+/]
    Agent.setup_current_callstate_for(peer, 'registered')

    AmqpManager.numbers_publish(event)
  end
end
