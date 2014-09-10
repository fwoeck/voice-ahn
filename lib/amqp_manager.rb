require './app/models/agent'


module AmqpManager

  class << self

    def rails_channel
      Thread.current[:rails_channel] ||= @connection.create_channel
    end

    def rails_xchange
      Thread.current[:rails_xchange] ||= rails_channel.topic('voice.rails', auto_delete: false)
    end


    def custom_channel
      Thread.current[:custom_channel] ||= @connection.create_channel
    end

    def custom_xchange
      Thread.current[:custom_xchange] ||= custom_channel.topic('voice.custom', auto_delete: false)
    end


    def numbers_channel
      Thread.current[:numbers_channel] ||= @connection.create_channel
    end

    def numbers_xchange
      Thread.current[:numbers_xchange] ||= numbers_channel.topic('voice.numbers', auto_delete: false)
    end


    def publish_call(payload)
      data = Marshal.dump(payload)

      rails_xchange.publish(data,   routing_key: 'voice.rails')
      custom_xchange.publish(data,  routing_key: 'voice.custom') if mailbox_message?(payload)
      numbers_xchange.publish(data, routing_key: 'voice.numbers')
    end


    def publish_agent(payload)
      data = Marshal.dump(payload)

      rails_xchange.publish(data,  routing_key: 'voice.rails')
      custom_xchange.publish(data, routing_key: 'voice.custom') if agent_takes_call?(payload)
    end


    # FIXME These filters shouldn't be here. Can we write
    #       more specific publish-methods?
    #
    def mailbox_message?(payload)
      !payload[:headers]['Mailbox'].blank?
    end
    #
    #
    def agent_takes_call?(payload)
      payload[:headers][:activity] == :talking &&
        payload[:headers][:extension] != AhnConfig.admin_name
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


    def shutdown!
      @connection.close
    end


    def establish_connection
      @connection = Bunny.new(
        host:     AhnConfig.rabbit_host,
        user:     AhnConfig.rabbit_user,
        password: AhnConfig.rabbit_pass
      ).tap { |c| c.start }
    rescue Bunny::TCPConnectionFailed
      sleep 1
      retry
    end


    def start
      establish_connection
      ahn_queue.bind(ahn_xchange, routing_key: 'voice.ahn')

      ahn_queue.subscribe { |delivery_info, metadata, payload|
        data = Marshal.load(payload)

        if data[:user_id]
          Agent.update_client_settings_with(data)
        elsif data[:command]
          Call.execute_command_with(data)
        end
      }
    end
  end
end
