Adhearsion.config do |config|

  config.production do |env|
    env.platform.logging.level = :info
  end

  config.development do |env|
    env.platform.logging.level = :info
  end

  config.punchblock.platform = :asterisk
  config.punchblock.username = WimConfig.ami_user
  config.punchblock.password = WimConfig.ami_pass
  config.punchblock.host     = WimConfig.ami_host

  plug = RUBY_PLATFORM =~ /java/ ? 'jdbc:mysql' : 'mysql2'
  db   = WimConfig.mysql_db
  host = WimConfig.mysql_host
  port = WimConfig.mysql_port
  user = WimConfig.mysql_user
  pass = WimConfig.mysql_pass

  config.sequella.uri         = "#{plug}://#{host}:#{port}/#{db}?user=#{user}&password=#{pass}"
  config.sequella.model_paths = ['./app/models']
end
