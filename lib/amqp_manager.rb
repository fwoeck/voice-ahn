module AMQPManager


  def self.numbers_channel
    Thread.current[:numbers_channel] ||= @connection.create_channel
  end


  def self.numbers_xchange
    Thread.current[:numbers_xchange] ||= numbers_channel.topic('voice.numbers', auto_delete: false)
  end


  def self.publish_to_numbers(*args)
    numbers_xchange.publish(*args)
  end


  def self.push_channel
    Thread.current[:push_channel] ||= @connection.create_channel
  end


  def self.push_xchange
    Thread.current[:push_xchange] ||= push_channel.fanout('voice.push', auto_delete: false)
  end


  def self.publish_to_push(*args)
    push_xchange.publish(*args)
  end


  def self.publish(event)
    json_evt = event.to_json
    publish_to_numbers(json_evt, routing_key: 'voice.numbers')
    publish_to_push(json_evt)
  end


  def self.shutdown
    @connection.close
  end


  def self.start
    @connection = Bunny.new(
      host:     AhnConfig['rabbit_host'],
      user:     AhnConfig['rabbit_user'],
      password: AhnConfig['rabbit_pass']
    )
    @connection.start

    numbers_channel.queue('voice.numbers', auto_delete: false)
                   .bind(numbers_xchange, routing_key: 'voice.numbers')
  end
end
