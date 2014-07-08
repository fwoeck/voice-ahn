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

  # FIXME refactor this urgently:
  #
  ami name: 'PeerStatus' do |event|
    peer   = event.headers['Peer'][/SIP.(.+)$/,1]
    status = event.headers['PeerStatus'].downcase
    search = Agent::Registry.detect { |k,v| v.name == peer }

    if search
      agent = search[1]
      agent.callstate = status
      $redis.set("#{WimConfig.rails_env}.callstate.#{agent.id}", status)
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
