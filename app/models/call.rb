CallRegistry = ThreadSafe::Cache.new


class Call
  extend Keynames

  Queues = ThreadSafe::Hash.new
  FORMAT = %w{call_id call_tag origin_id language skill extension caller_id hungup called_at mailbox queued_at hungup_at dispatched_at}
           .map(&:to_sym)

  attr_accessor *FORMAT


  def initialize(par={})
    FORMAT.each do |sym|
      self.send "#{sym}=", par.fetch(sym, nil)
    end
  end


  def save(expires=3.hours, publish=true)
    dump = Marshal.dump(self)

    RPool.with { |con|
      con.set(Call.call_keyname(call_id), dump, {ex: expires})
    }
    publish_update(dump) if publish
  end


  def destroy
    self.hungup    = true
    self.hungup_at = Time.now.utc
    save(1.minute)
  end


  def publish_update(dump)
    AmqpManager.publish(dump, mailbox_message?, true)
  end


  def mailbox_message?
    !mailbox.blank?
  end


  def update_state_for(hdr)
    detect_callers_for(hdr)
    detect_call_tag_for(hdr)
    detect_extension_for(hdr)
    save
  end


  def detect_callers_for(hdr)
    return if self.caller_id

    num = hdr['CallerIDNum']
    num = nil if (num.blank? || num == 'Anonymous')

    self.caller_id = (num || hdr['CallerIDName']).sub('SIP/', '').sub(/@.+$/, '')
    self.called_at = Time.now.utc
  end


  def detect_call_tag_for(hdr)
    chan1 = hdr['Channel1']
    chan2 = hdr['Channel2']

    if chan2
      self.call_tag = "#{chan1} #{chan2}"
      self.dispatched_at ||= Time.now.utc
    end
  end


  def detect_extension_for(hdr)
    return if self.extension

    chan = hdr['Channel1'] || hdr['Channel'] || ""
    ext  = chan[ChannelRegex, 1] || '0'
    ext  = '0' if ext == AhnConfig.admin_name

    self.extension = ext
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


    def close_state_for(event)
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
