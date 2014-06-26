# encoding: utf-8
ENV['TZ'] = 'UTC'

require 'yaml'
require 'bundler'
Bundler.setup
require 'adhearsion'
require 'active_support/all'

AhnConfig = YAML.load_file('./config/app.yml')
Time.zone = 'Etc/UTC'

Bundler.require(:default, Adhearsion.environment)
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../app/')))

# RedisDb = ConnectionPool::Wrapper.new(size: 5, timeout: 3) {
#   Redis.new(host: AhnConfig['redis_host'], port: AhnConfig['redis_port'], db: AhnConfig['redis_db'])
# }

Signal.trap('TERM') do
  AmqpManager.shutdown
  Adhearsion::Process.shutdown
  exit!
end
