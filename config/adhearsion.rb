# encoding: utf-8

Adhearsion.config do |config|

  # Centralized way to specify any Adhearsion platform or plugin configuration
  # - Execute rake config:show to view the active configuration values
  #
  # To update a plugin configuration you can write either:
  #
  #    * Option 1
  #        Adhearsion.config.<plugin-name> do |config|
  #          config.<key> = <value>
  #        end
  #
  #    * Option 2
  #        Adhearsion.config do |config|
  #          config.<plugin-name>.<key> = <value>
  #        end

  config.development do |dev|
    dev.platform.logging.level = :info
  end

  config.adhearsion_activerecord.adapter     = (RUBY_PLATFORM =~ /java/ ? 'jdbcmysql' : 'mysql2')
  config.adhearsion_activerecord.database    = 'asterisk'
  config.adhearsion_activerecord.model_paths = []
  config.adhearsion_activerecord.socket      = '/var/run/mysqld/mysqld.sock'
# config.adhearsion_activerecord.host        =
# config.adhearsion_activerecord.port        =
  config.adhearsion_activerecord.username    = 'astrealtime'
  config.adhearsion_activerecord.password    = '***REMOVED***'
  config.adhearsion_activerecord.pool        = 100

  config.punchblock.platform = :asterisk
  config.punchblock.username = 'ahn_ami'
  config.punchblock.password = '***REMOVED***'
  config.punchblock.host     = '127.0.0.1'
end
