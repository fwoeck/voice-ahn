module AMQPManager

  def self.ahn_channel
    Thread.current[:ahn_channel] ||= @connection.create_channel
  end

  def self.ahn_xchange
    Thread.current[:ahn_xchange] ||= ahn_channel.topic('voice.ahn', auto_delete: false)
  end

  def self.ahn_publish(*args)
    ahn_xchange.publish(*args)
  end


  def self.push_channel
    Thread.current[:push_channel] ||= @connection.create_channel
  end

  def self.push_xchange
    Thread.current[:push_xchange] ||= push_channel.fanout('voice.push', auto_delete: false)
  end

  def self.push_publish(*args)
    push_xchange.publish(*args)
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

    ahn_channel.queue('voice.ahn', auto_delete: false)
               .bind(ahn_xchange, routing_key: 'voice.ahn')
  end
end
