source 'http://rubygems.org'

gem 'i18n'
gem 'bunny'
gem 'ruby_ami'
gem 'adhearsion'
gem 'punchblock'
gem 'adhearsion-asr'
gem 'adhearsion-drb'
gem 'connection_pool'
gem 'adhearsion-asterisk'
gem 'adhearsion-activerecord'

gem 'activesupport', '< 4.0.0' # see https://github.com/adhearsion/adhearsion-activerecord/pull/3

platforms :ruby do
  gem 'mysql2'
end

platforms :jruby do
  gem 'activerecord-jdbc-adapter'
  gem 'activerecord-jdbcmysql-adapter'
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
