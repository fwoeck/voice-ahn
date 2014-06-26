# encoding: utf-8

Adhearsion.config do |config|

  config.production do |env|
    env.platform.logging.level = :info
  end

  config.development do |env|
    env.platform.logging.level = :info
  end

  config.punchblock.platform = :asterisk
  config.punchblock.username = AhnConfig['ami_user']
  config.punchblock.password = AhnConfig['ami_pass']
  config.punchblock.host     = AhnConfig['ami_host']

  plug = RUBY_PLATFORM =~ /java/ ? 'jdbc:mysql' : 'mysql2'
  db   = AhnConfig['mysql_db']
  sock = AhnConfig['mysql_sock']
  host = AhnConfig['mysql_host']
  port = AhnConfig['mysql_port']
  user = AhnConfig['mysql_user']
  pass = AhnConfig['mysql_pass']

  config.sequella.uri         = "#{plug}://#{host}:#{port}/#{db}?user=#{user}&password=#{pass}"
  config.sequella.model_paths = ['./app/models']

  # config.adhearsion_drb.acl.allow     = [AhnConfig['drb_host']]
  # config.adhearsion_drb.acl.deny      = []
  # config.adhearsion_drb.host          = AhnConfig['drb_host']
  # config.adhearsion_drb.port          = AhnConfig['drb_port']
  # config.adhearsion_drb.shared_object = Ahn
end
