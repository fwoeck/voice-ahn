# encoding: utf-8
require 'json'

CallRegistry = ThreadSafe::Cache.new


class Call
  extend Keynames

  Queues = ThreadSafe::Hash.new
  FORMAT = %w{call_id call_tag language skill extension caller_id hungup called_at mailbox queued_at hungup_at dispatched_at}
           .map(&:to_sym)

  attr_accessor *FORMAT


  def initialize(par={})
    FORMAT.each do |sym|
      self.send "#{sym}=", par.fetch(sym, nil)
    end
  end


  def save(expires=3.hours, publish=true)
    dump = Marshal.dump(self)
    Redis.current.set(Call.call_keyname(call_id), dump, {ex: expires})
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
    chan1 = hdr['Channel1'] || hdr['Channel']
    chan2 = hdr['Channel2']

    if chan2
      self.call_tag = "#{chan1}_#{chan2}"
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

    def threaded_call_update(tcid, &block)
      return unless tcid
      Thread.new { lock_for_call(tcid, block) }
    end


    def lock_for_call(tcid, block)
      (CallRegistry[tcid] ||= Mutex.new).tap { |mutex|
        mutex.synchronize { block.call }
      }
    end


    def set_lang_and_skill_for(tcid, lang, skill)
      sleep 0.1 # FIXME Why is this exactly necessary?

      threaded_call_update(tcid) do
        call = find(tcid)

        call.tap { |c|
          c.language = lang
          c.skill    = skill
        }.save(3.hours, false) if call
      end
    end


    def set_language_for(tcid, lang)
      threaded_call_update(tcid) do
        call = find(tcid)
        call.tap { |c| c.language = lang }.save if call
      end
    end


    def set_skill_for(tcid, skill)
      threaded_call_update(tcid) do
        call = find(tcid)
        call.tap { |c| c.skill = skill }.save if call
      end
    end


    def set_dispatched_at(tcid)
      threaded_call_update(tcid) do
        call = find(tcid)
        call.tap { |c| c.dispatched_at = Time.now.utc }.save if call
      end
    end


    def set_queued_at(tcid)
      threaded_call_update(tcid) do
        call = find(tcid)
        call.tap { |c| c.queued_at = Time.now.utc }.save if call
      end
    end


    def set_mailbox(tcid, mid)
      threaded_call_update(tcid) do
        call = find(tcid)
        call.tap { |c| c.mailbox = mid }.destroy if call
      end
    end


    def find(tcid)
      return unless tcid
      call = Redis.current.get(call_keyname tcid)
      Marshal.load(call) if call
    end


    def close_state_for(event)
      tcid = event.target_call_id

      threaded_call_update(tcid) do
        call = Call.find(tcid)
        call.destroy if call
      end
    end


    def update_state_for(event)
      return unless (tcid = event.target_call_id)
      hdr = event.headers

      threaded_call_update(tcid) do
        call = Call.find(tcid) || Call.new(call_id: tcid)
        if call && !call.hungup
          call.update_state_for(hdr)
        end
      end
    end


    def clear_all_redis_calls
      Redis.current.keys(call_keypattern).each { |key| Redis.current.del(key) }
    rescue Redis::CannotConnectError
      sleep 1
      retry
    end
  end
end
