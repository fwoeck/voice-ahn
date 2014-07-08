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
    AmqpManager.numbers_publish(event)

    peer   = event.headers['Peer'][/SIP.(.+)$/,1]
    status = event.headers['PeerStatus']
  end

  ami name: 'NewCallerid' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'OriginateResponse' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'Newstate' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'Newchannel' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'SoftHangupRequest' do |event|
    AmqpManager.numbers_publish(event)
  end

  ami name: 'Hangup' do |event|
    AmqpManager.numbers_publish(event)
  end
end
