class CallRpc

  attr_accessor :call_id, :command, :to, :from


  def handle_update
    self.send command
  end


  def call_to_trunk?
    to.length > 4
  end


  def originate
    _from = "SIP/#{from}"
    _to   = call_to_trunk? ? "#{to} <#{to}@sipconnect.sipgate.de>" : "SIP/#{to}"

    # FIXME Transfer of a call originated by us will fail, because
    #       a controller is needed to store the metadata:
    #
    Adhearsion::OutboundCall.originate(_from, from: _to) do
      opts = {for: DialTimeout.seconds}
      opts[:from] = _from unless call_to_trunk?
      dial _to, opts
    end
  end


  def transfer
    call = find_ahn_call
    call.auto_hangup = false

    cdial = call.controllers.first.metadata['current_dial']
    execute_transfer(call, cdial)
  end


  def execute_transfer(call, cdial)
    call.execute_controller do
      begin
        cdial.cleanup_calls
        tdial = Adhearsion::CallController::Dial::Dial.new("SIP/#{to}", {}, call)
        metadata['current_dial'] = tdial

        tdial.run self
        tdial.await_completion
        tdial.cleanup_calls
      ensure
        hangup
      end
    end
  end


  def hangup
    if (call = find_ahn_call)
      call.pause_controllers
      call.hangup
    end
  end


  def find_ahn_call
    Adhearsion.active_calls.values.find { |c| c.id == call_id }
  end
end
