# encoding: utf-8
ENV['TZ'] = 'UTC'

require 'yaml'
require 'bundler'
Bundler.setup
require 'adhearsion'

AhnConfig = YAML.load_file('./config/app.yml')
Time.zone = 'Etc/UTC'

Bundler.require(:default, Adhearsion.environment)
$LOAD_PATH.unshift(File.expand_path(File.join(File.dirname(__FILE__), '../app/')))
