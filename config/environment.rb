# encoding: utf-8
#
require 'yaml'
require 'bundler'
Bundler.setup

require 'adhearsion'
require 'active_support/all'


Time.zone = 'Etc/UTC'
WimConfig = YAML.load_file('./config/app.yml')
WimConfig.keys.each { |key|
  WimConfig.instance_eval "class << self; define_method(:#{key}) {self['#{key}']}; end"
}


Bundler.require(:default, Adhearsion.environment)
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../app/')))


Signal.trap('TERM') do
  AmqpManager.shutdown
  Adhearsion::Process.shutdown
  exit!
end
