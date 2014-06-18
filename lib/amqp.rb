module AMQPManager

  def self.channel
    Thread.current[:channel] ||= @connection.create_channel
  end

  def self.xchange
    Thread.current[:xchange] ||= channel.topic('voice.ahn', auto_delete: false)
  end

  def self.ahn_publish(*args)
    xchange.publish(*args)
  end

  def self.shutdown
    @connection.close
  end

  def self.start
    @connection = Bunny.new(host: AhnConfig['rabbit_host'], user: AhnConfig['rabbit_user'], password: AhnConfig['rabbit_pass'])
    @connection.start

    channel.queue('voice.ahn', auto_delete: false).bind(xchange, routing_key: 'voice.ahn')
  end
end
