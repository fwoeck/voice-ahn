# encoding: utf-8

Adhearsion::Events.draw do

  punchblock do |event|
    AMQPManager.push_publish(event.to_json)
    AMQPManager.ahn_publish(event.to_json, routing_key: 'voice.ahn')
  end

  # ami name: 'PeerStatus' do |event|
  #   puts event
  # end
end
