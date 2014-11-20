LogObject   = Struct.new(:time, :data, :custom, :numbers)
MESSAGE_LOG = ThreadSafe::Array.new


class AmqpManager
  include Celluloid

  USE_JRB = RUBY_PLATFORM =~ /java/
  TOPICS  = [:rails, :numbers, :custom, :ahn]


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


  def publish(data, incl_custom, incl_numbers)
    publish_to(:rails,   data)
    publish_to(:custom,  data) if incl_custom
    publish_to(:numbers, data) if incl_numbers

    capture_message(data, incl_custom, incl_numbers)
  end


  def capture_message(data, incl_custom, incl_numbers)
    return unless ENV['CAPTURE']
    MESSAGE_LOG << LogObject.new(Time.now.utc, data, incl_custom, incl_numbers)
  end


  def publish_to(target, data)
    return if User.shutdown?
    self.send("#{target}_xchange").publish(data, routing_key: "voice.#{target}")
  end


  def connection
    establish_connection unless @@connection
    @@connection
  end


  def shutdown
    connection.close
  end


  def establish_connection
    sleep 1 while !users_are_ready?
    USE_JRB ? establish_marchhare_connection : establish_bunny_connection
  end


  def establish_bunny_connection
    @@connection = Bunny.new(amqp_config).tap { |c| c.start }
  rescue Bunny::TCPConnectionFailed
    sleep 1
    retry
  end


  def establish_marchhare_connection
    @@connection = MarchHare.connect(amqp_config)
  rescue MarchHare::ConnectionRefused
    sleep 1
    retry
  end


  def amqp_config
    { host:     AhnConfig.rabbit_host,
      user:     AhnConfig.rabbit_user,
      password: AhnConfig.rabbit_pass
    }
  end


  def users_are_ready?
    defined?(User) && User.respond_to?(:ready?) && User.ready?
  end


  def start
    establish_connection
    ahn_queue.bind(ahn_xchange, routing_key: 'voice.ahn')

    ahn_queue.subscribe(blocking: false) do |*args|
      Marshal.load(USE_JRB ? args[0] : args[2]).handle_message
    end
  end


  class << self

    def start
      Celluloid.logger.level = 3
      Celluloid::Actor[:amqp] = AmqpManager.pool(size: 32)
      @@manager ||= new.tap { |m| m.start }
    end


    def shutdown
      @@manager.shutdown
    end


    def publish(*args)
      Celluloid::Actor[:amqp].async.publish(*args)
    end


    def dump_filename(file)
      './log/' + (file || "capture-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}") + '.yml'
    end


    def dump_log(file=nil)
      File.open(dump_filename(file), 'wb') { |f| f.write MESSAGE_LOG.to_yaml }
      MESSAGE_LOG.clear
    end
  end
end
