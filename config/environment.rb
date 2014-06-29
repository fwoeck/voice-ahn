# encoding: utf-8
#
require 'yaml'
require 'bundler'
Bundler.setup

require 'adhearsion'
require 'active_support/all'


AhnConfig = YAML.load_file('./config/app.yml')
Time.zone = 'Etc/UTC'


Bundler.require(:default, Adhearsion.environment)
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../app/')))


Signal.trap('TERM') do
  AmqpManager.shutdown
  Adhearsion::Process.shutdown
  exit!
end
