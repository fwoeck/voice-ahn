require './app/models/agent'


class AmqpManager
  include Celluloid

  TOPICS = [:rails, :numbers, :custom, :ahn]


  def publish(data, include_custom, include_numbers)
    rails_xchange.publish(data, routing_key: 'voice.rails')
    custom_xchange.publish(data, routing_key: 'voice.custom') if include_custom
    numbers_xchange.publish(data, routing_key: 'voice.numbers') if include_numbers
  end


  TOPICS.each { |name|
    sym = "@#{name}_channel".to_sym
    define_method "#{name}_channel" do
      instance_variable_get(sym) || instance_variable_set(
        sym, connection.create_channel
      )
    end

    sym = "@#{name}_xchange".to_sym
    define_method "#{name}_xchange" do
      instance_variable_get(sym) || instance_variable_set(
        sym, send("#{name}_channel").topic("voice.#{name}", auto_delete: false)
      )
    end

    sym = "@#{name}_queue".to_sym
    define_method "#{name}_queue" do
      instance_variable_get(sym) || instance_variable_set(
        sym, send("#{name}_channel").queue("voice.#{name}", auto_delete: false)
      )
    end
  }


  def connection
    establish_connection unless @@connection
    @@connection
  end


  def shutdown!
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
      @@manager ||= new.tap { |m| m.start }
    end


    def shutdown!
      @@manager.shutdown!
    end


    def publish(*args)
      Celluloid::Actor[:amqp].async.publish(*args)
    end
  end
end
