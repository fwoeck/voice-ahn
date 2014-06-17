# encoding: utf-8

class DefaultContext < Adhearsion::CallController

  def run
    log_call
    answer
    play 'letters/a'
    status = dial 'SIP/101', for: 8.seconds

    case status.result
    when :answer
      play 'letters/b'
    else
      play 'letters/x'
    end
  end

  def log_call
    logger.info "Call from: #{call.from}, id: #{call.variables[:x_agi_callerid]}, chan: #{call.variables[:x_agi_channel]}"
  end
end
