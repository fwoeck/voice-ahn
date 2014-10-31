class CallActor
  include Celluloid

  attr_reader :call


  def initialize(tcid)
    @call = ::Call.new(call_id: tcid)
  end


  def set_params(qs)
    call.tap { |c|
      c.language  = qs.language
      c.origin_id = qs.call_id
      c.skill     = qs.skill
    }.save(3.hours, false) if call
  end


  def set_language(lang)
    call.tap { |c| c.language = lang }.save if call
  end


  def set_skill(skill)
    call.tap { |c| c.skill = skill }.save if call
  end


  def set_dispatched_at
    call.tap { |c| c.dispatched_at = Time.now.utc }.save if call
  end


  def set_queued_at
    call.tap { |c| c.queued_at = Time.now.utc }.save if call
  end


  def set_mailbox(mid)
    call.tap { |c| c.mailbox = mid }.destroy if call
  end


  def close_state
    call.destroy if call
  end


  def update_state(hdr)
    if call && !call.hungup_at
      call.update_state_for(hdr)
    end
  end
end
