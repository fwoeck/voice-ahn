source 'http://rubygems.org'

gem 'i18n'
gem 'bunny'
gem 'redis'
gem 'sequella'
gem 'ruby_ami'
gem 'adhearsion'
gem 'punchblock'
gem 'activesupport'
gem 'adhearsion-asr'
gem 'adhearsion-drb'
gem 'connection_pool'
gem 'adhearsion-asterisk'

platforms :ruby do
  gem 'mysql2'
end

platforms :jruby do
  gem 'jdbc-mysql'
end

platforms :rbx do
  gem 'rubysl'
end

group :development, :test do
  gem 'rspec'
  gem 'hirb',             require: false
  gem 'wirble',           require: false
  gem 'git-smart',        require: false
  gem 'rubygems-bundler', require: false
end
