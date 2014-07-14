require './app/models/agent'

module AmqpManager
  class << self

    def numbers_channel
      Thread.current[:numbers_channel] ||= @connection.create_channel
    end

    def numbers_xchange
      Thread.current[:numbers_xchange] ||= numbers_channel.topic('voice.numbers', auto_delete: false)
    end

    def numbers_publish(payload)
      sanitize_encoding_for(payload)
      numbers_xchange.publish(payload.to_json, routing_key: 'voice.numbers')
    end


    def sanitize_encoding_for(payload)
      return unless payload['headers']

      payload['headers'].keys.each do |key|
        if payload['headers'][key].is_a?(String)
          payload['headers'][key].force_encoding('UTF-8')
        end
      end
    end


    def ahn_channel
      Thread.current[:ahn_channel] ||= @connection.create_channel
    end

    def ahn_xchange
      Thread.current[:ahn_xchange] ||= ahn_channel.topic('voice.ahn', auto_delete: false)
    end

    def ahn_queue
      Thread.current[:ahn_queue] ||= ahn_channel.queue('voice.ahn', auto_delete: false)
    end


    def shutdown
      @connection.close
    end


    def establish_connection
      @connection = Bunny.new(
        host:     WimConfig.rabbit_host,
        user:     WimConfig.rabbit_user,
        password: WimConfig.rabbit_pass
      ).tap { |c| c.start }
    rescue Bunny::TCPConnectionFailed
      sleep 1
      retry
    end


    def start
      establish_connection
      ahn_queue.bind(ahn_xchange, routing_key: 'voice.ahn')

      ahn_queue.subscribe { |delivery_info, metadata, payload|
        data = JSON.parse(payload)

        if data['user_id']
          Agent.update_agent_state_with(data)
        elsif data['call_id']
          Call.execute_command_with(data)
        end
      }
    end
  end
end
