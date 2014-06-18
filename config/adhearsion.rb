# encoding: utf-8

RedisDb = ConnectionPool::Wrapper.new(size: 5, timeout: 3) {
  Redis.new(host: AhnConfig['redis_host'], port: AhnConfig['redis_port'], db: AhnConfig['redis_db'])
}

Adhearsion.config do |config|

  config.development do |dev|
    dev.platform.logging.level = :info
  end

  config.production do |env|
    env.platform.logging.level = :info
  end

  config.punchblock.platform = :asterisk
  config.punchblock.username = AhnConfig['ami_user']
  config.punchblock.password = AhnConfig['ami_pass']
  config.punchblock.host     = AhnConfig['ami_host']

  config.adhearsion_activerecord.adapter     = (RUBY_PLATFORM =~ /java/ ? 'jdbcmysql' : 'mysql2')
  config.adhearsion_activerecord.database    = AhnConfig['mysql_db']
  config.adhearsion_activerecord.model_paths = []
  config.adhearsion_activerecord.socket      = AhnConfig['mysql_sock']
# config.adhearsion_activerecord.host        = AhnConfig['mysql_host']
# config.adhearsion_activerecord.port        = AhnConfig['mysql_port']
  config.adhearsion_activerecord.username    = AhnConfig['mysql_user']
  config.adhearsion_activerecord.password    = AhnConfig['mysql_pass']
  config.adhearsion_activerecord.pool        = 100

end
