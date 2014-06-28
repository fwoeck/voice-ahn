# encoding: utf-8

Adhearsion::Events.draw do

  # punchblock do |event|
  # end

  # Common events:
  #   New|DTMF|PeerStatus|Originate|Masquerade|Rename|Bridge|Hangup|SoftHangup
  #
  ami name: 'PeerStatus' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'DTMF' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Hangup' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'SoftHangup' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Hangup' do |event|
    AMQPManager.publish(event)
  end

  ami name: 'Bridge' do |event|
    AMQPManager.publish(event)
  end
end
