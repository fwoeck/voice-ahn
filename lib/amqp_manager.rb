module AMQPManager
  class << self


    def numbers_channel
      Thread.current[:numbers_channel] ||= @connection.create_channel
    end


    def numbers_xchange
      Thread.current[:numbers_xchange] ||= numbers_channel.topic('voice.numbers', auto_delete: false)
    end


    def numbers_publish(payload)
      numbers_xchange.publish(payload.to_json, routing_key: 'voice.numbers')
    end


    def shutdown
      @connection.close
    end


    def start
      @connection = Bunny.new(
        host:     AhnConfig['rabbit_host'],
        user:     AhnConfig['rabbit_user'],
        password: AhnConfig['rabbit_pass']
      )
      @connection.start

      numbers_channel.queue('voice.numbers', auto_delete: false)
                     .bind(numbers_xchange, routing_key: 'voice.numbers')
    rescue Bunny::TCPConnectionFailed
      sleep 1
      retry
    end
  end
end
