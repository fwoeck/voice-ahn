require './app/models/agent'


module AmqpManager
  TOPICS = [:rails, :numbers, :custom, :ahn]

  class << self

    def close_channels
      TOPICS.each { |name| Thread.current["#{name}_channel".to_sym].try(:close) }
    end


    TOPICS.each { |name|
      define_method "#{name}_channel" do
        Thread.current["#{name}_channel".to_sym] ||= connection.create_channel
      end

      define_method "#{name}_xchange" do
        Thread.current["#{name}_xchange".to_sym] ||= send("#{name}_channel").topic("voice.#{name}", auto_delete: false)
      end

      define_method "#{name}_queue" do
        Thread.current["#{name}_queue".to_sym] ||= send("#{name}_channel").queue("voice.#{name}", auto_delete: false)
      end
    }


    def publish(data, include_custom, include_numbers)
      Thread.new {
        rails_xchange.publish(data,   routing_key: 'voice.rails')
        custom_xchange.publish(data,  routing_key: 'voice.custom')  if include_custom
        numbers_xchange.publish(data, routing_key: 'voice.numbers') if include_numbers

        close_channels
      }
    end


    def connection
      establish_connection unless @connection
      @connection
    end


    def shutdown!
      connection.close
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
