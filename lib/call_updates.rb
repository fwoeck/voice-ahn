module CallUpdates

  def save(expires=3.hours, publish=true)
    dump = Marshal.dump(self)

    RPool.with { |con|
      con.set(Call.call_keyname(call_id), dump, {ex: expires})
    }
    publish_update(dump) if publish
  end


  def destroy
    self.hungup_at = Time.now.utc
    save(1.minute)
  end


  def update_state_for(hdr)
    detect_callers_for(hdr)
    detect_call_tag_for(hdr)
    detect_extension_for(hdr)
    save
  end


  def detect_callers_for(hdr)
    return unless caller_id.blank?

    self.caller_id = extract_caller_id_from(hdr)
    self.called_at = Time.now.utc
  end


  def extract_caller_id_from(hdr)
    num = hdr['CallerIDNum']
    num = nil if (num.blank? || num == 'Anonymous')
    (num || hdr['CallerIDName'] || '').sub('SIP/', '').sub(/@.+$/, '')
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
    ext  = chan[AgentRegex, 1] || '0'
    ext  = '0' if ext == AhnConfig.admin_name

    self.extension = ext
  end


  def publish_update(dump)
    AmqpManager.publish(dump, mailbox_message?, true)
  end


  def mailbox_message?
    !mailbox.blank?
  end
end
