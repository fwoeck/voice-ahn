source 'http://rubygems.org'

gem 'i18n'
gem 'bunny'
gem 'redis'
gem 'sequella'
gem 'ruby_ami',            github: 'adhearsion/ruby_ami',            branch: 'develop'
gem 'adhearsion',          github: 'adhearsion/adhearsion',          branch: 'develop'
gem 'punchblock',          github: 'adhearsion/punchblock',          branch: 'develop'
gem 'activesupport'
gem 'adhearsion-asr',      github: 'adhearsion/adhearsion-asr',      branch: 'develop'
gem 'connection_pool'
gem 'adhearsion-asterisk', github: 'adhearsion/adhearsion-asterisk', branch: 'develop'

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
