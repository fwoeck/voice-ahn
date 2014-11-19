module PostProcessing

  def cleanup_leftovers
    Call::Queues.delete call_id
    @call_id = @qs = nil
  end


  def timeout_call
    stop_moh
    qs.dispatched = true
    qs.status     = :timeout
    Call.set_dispatched_at(call_id)
  end


  def record_voice_memo
    # TODO
    #   We need a goodbye message if voicemail is switched off:
    return unless AhnConfig.vm_available

    play "wimdu/#{qs.language}_leave_a_message"
    result = record start_beep: true, max_duration: AhnConfig.vm_timeout
    postprocess_recording result.recording_uri
  end


  def postprocess_recording(uri)
    rid = uri[/[0-9a-f-]{10,}/]

    Call.set_mailbox(call_id, rid)
    # FIXME
    #   Long recordings are not properly transcoded (cut after 1:40).
    #   Maybe the thread dies before sox finished?
    Thread.new {
      system "sox --norm=-1 #{AhnConfig.mp3_source}/#{rid}.wav -C 128.2 #{AhnConfig.mp3_target}/#{rid}.mp3"
    }
  end
end
