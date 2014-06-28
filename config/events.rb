# encoding: utf-8

Adhearsion::Events.draw do

  # punchblock do |event|
  #   puts event
  # end

  ami name: 'Bridge' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'BridgeExec' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'PeerStatus' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'NewCallerid' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'OriginateResponse' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Newstate' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Newchannel' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'SoftHangupRequest' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Hangup' do |event|
    AMQPManager.publish(event)
  end
end
