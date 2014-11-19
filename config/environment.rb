ENV['TZ']     = 'UTC'
ENV['LANG']   = 'en_US.UTF-8'
ENV['LC_ALL'] = 'en_US.UTF-8'

require 'yaml'
require 'bundler'
Bundler.setup

require 'adhearsion'
require 'active_support/all'


Time.zone = 'Etc/UTC'
I18n.enforce_available_locales = false

AhnConfig   = YAML.load_file('./config/app.yml')
AhnConfig.keys.each { |key|
  AhnConfig.instance_eval "class << self; define_method(:#{key}) {self['#{key}']}; end"
}


Bundler.require(:default, Adhearsion.environment)
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../app/')))
