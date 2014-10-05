module PostProcessing

  def cleanup_leftovers
    Call::Queues.delete call_id
    @call_id = @qs = nil
  end


  def record_voice_memo
    qs.status = :timeout
    Call.set_dispatched_at(call_id)

    stop_moh
    play "wimdu/#{qs.language}_leave_a_message"

    result = record start_beep: true, max_duration: 60_000
    postprocess_recording result.recording_uri
  rescue
    # Usually happens, because qs has been removed.
  end


  def postprocess_recording(uri)
    rid = uri[/[0-9a-f-]{10,}/]

    Call.set_mailbox(call_id, rid)
    Thread.new {
      system "sox --norm=-1 #{AhnConfig.mp3_source}/#{rid}.wav -C 128.2 #{AhnConfig.mp3_target}/#{rid}.mp3"
    }
  end
end
