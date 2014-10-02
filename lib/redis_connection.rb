require 'connection_pool'
require 'redis'


RPool = ConnectionPool.new(size: 5, timeout: 3) {
  Redis.new(
    host: AhnConfig['redis_host'],
    port: AhnConfig['redis_port'],
    db:   AhnConfig['redis_db']
  )
}
