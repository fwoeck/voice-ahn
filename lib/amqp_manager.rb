class AmqpManager
  include Celluloid

  TOPICS = [:rails, :numbers, :custom, :ahn]


  TOPICS.each { |name|
    class_eval %Q"
      def #{name}_channel
        @#{name}_channel ||= connection.create_channel
      end
    "

    class_eval %Q"
      def #{name}_xchange
        @#{name}_xchange ||= #{name}_channel.topic('voice.#{name}', auto_delete: false)
      end
    "

    class_eval %Q"
      def #{name}_queue
        @#{name}_queue ||= #{name}_channel.queue('voice.#{name}', auto_delete: false)
      end
    "
  }


  def publish(data, to_custom, to_numbers)
    rails_xchange.publish(data, routing_key: 'voice.rails')
    custom_xchange.publish(data, routing_key: 'voice.custom') if to_custom
    numbers_xchange.publish(data, routing_key: 'voice.numbers') if to_numbers
  end


  def connection
    establish_connection unless @@connection
    @@connection
  end


  def shutdown
    connection.close
  end


  def establish_connection
    @@connection = Bunny.new(
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
      data.handle_update
    }
  end


  class << self

    def start
      # TODO This will suppress warnings at exit, but could also
      #       mask potential problems. Try to remove after a while:
      #
      Celluloid.logger = nil

      Celluloid::Actor[:amqp] = AmqpManager.pool
      @@manager ||= new.tap { |m| m.start }
    end


    def shutdown
      @@manager.shutdown
    end


    def publish(*args)
      Celluloid::Actor[:amqp].async.publish(*args)
    end
  end
end
