require './lib/call_updates'

CallRegistry = ThreadSafe::Cache.new


class Call
  include CallUpdates
  extend Keynames


  Queues = ThreadSafe::Hash.new
  FORMAT = %w{call_id call_tag origin_id language skill extension caller_id called_at mailbox queued_at hungup_at dispatched_at}
           .map(&:to_sym)

  attr_accessor *FORMAT


  def initialize(par={})
    FORMAT.each do |sym|
      self.send "#{sym}=", par.fetch(sym, nil)
    end
  end


  class << self

    def find(tcid)
      CallRegistry[tcid] ||= CallActor.new(tcid)
    end


    def set_params_for(tcid, qs)
      find(tcid).async.set_params(qs)
    end


    def set_language_for(tcid, lang)
      find(tcid).async.set_language(lang)
    end


    def set_skill_for(tcid, skill)
      find(tcid).async.set_skill(skill)
    end


    def set_dispatched_at(tcid)
      find(tcid).async.set_dispatched_at
    end


    def set_queued_at(tcid)
      find(tcid).async.set_queued_at
    end


    def set_mailbox(tcid, mid)
      find(tcid).async.set_mailbox(mid)
    end


    def set_close_state_for(event)
      return unless (tcid = event.target_call_id)
      find(tcid).async.close_state
    end


    def update_state_for(event)
      return unless (tcid = event.target_call_id)
      find(tcid).async.update_state(event.headers)
    end


    def clear_all_redis_calls
      RPool.with { |con|
        con.keys(call_keypattern)
      }.each { |key|
        RPool.with { |con| con.del(key) }
      }
    rescue Redis::CannotConnectError
      sleep 1
      retry
    end
  end
end
