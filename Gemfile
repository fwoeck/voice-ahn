source 'http://rubygems.org'

gem 'i18n'
gem 'bunny', '1.5.1'        # FIXME 1.6.0 hangs with jruby
gem 'redis'
gem 'sequella'
gem 'ruby_ami',             github: 'adhearsion/ruby_ami',             branch: 'develop'
gem 'adhearsion',           github: 'adhearsion/adhearsion',           branch: 'develop'
gem 'punchblock',           github: 'adhearsion/punchblock',           branch: 'develop'
gem 'activesupport'
gem 'adhearsion-asr',       github: 'adhearsion/adhearsion-asr',       branch: 'develop'
gem 'connection_pool'
gem 'adhearsion-asterisk',  github: 'adhearsion/adhearsion-asterisk',  branch: 'develop'
gem 'has-guarded-handlers', github: 'adhearsion/has-guarded-handlers', branch: 'develop'

gem 'celluloid'

platforms :ruby do
  gem 'mysql2'
end

platforms :jruby do
  gem 'jdbc-mysql'
end

group :test do
  gem 'rspec'
end
