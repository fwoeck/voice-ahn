Adhearsion.config do |config|

  config.production do |env|
    env.platform.logging.level = :warn
    env.platform.after_hangup_lifetime = 30
  end

  config.development do |env|
    env.platform.logging.level = :info
    env.platform.after_hangup_lifetime = 30
  end


  config.punchblock.platform = :asterisk
  config.punchblock.username = AhnConfig.ami_user
  config.punchblock.password = AhnConfig.ami_pass
  config.punchblock.host     = AhnConfig.ami_host


  plug = RUBY_PLATFORM =~ /java/ ? 'jdbc:mysql' : 'mysql2'
  db   = AhnConfig.mysql_db
  host = AhnConfig.mysql_host
  port = AhnConfig.mysql_port
  user = AhnConfig.mysql_user
  pass = AhnConfig.mysql_pass


  config.sequella.uri         = "#{plug}://#{host}:#{port}/#{db}?user=#{user}&password=#{pass}"
  config.sequella.model_paths = ['./app/models']
end
