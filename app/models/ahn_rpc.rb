class AhnRpc

  attr_accessor :call_id, :command, :to, :from


  def handle_message
    self.send command
  end


  def call_to_trunk?
    to.length > 4
  end


  def originate
    _from = "SIP/#{from}"
    _to   = call_to_trunk? ? "SIP/#{to}@sipconnect.sipgate.de" : "SIP/#{to}"

    # FIXME Transfer of a call originated by us will fail. Maybe, because
    #       a controller is needed to store the metadata:
    #
    Adhearsion::OutboundCall.originate(_from, from: _to) do
      opts = {for: DialTimeout.seconds}
      opts[:from] = _from unless call_to_trunk?

      cd = Adhearsion::CallController::Dial::Dial.new(_to, opts, call)
      metadata['current_dial'] = cd
      execute_dial(cd, Call.find(call.id).call)
    end
  end


  def transfer
    if (ahn_call = find_ahn_call)
      ahn_call.auto_hangup = false

      cdial = ahn_call.controllers.first.metadata['current_dial']
      execute_transfer(ahn_call, cdial, Call.find(ahn_call.id).call)
    end
  end


  def execute_transfer(ahn_call, cdial, call)
    ahn_call.execute_controller do
      begin
        cdial.cleanup_calls
        tdial = Adhearsion::CallController::Dial::Dial.new("SIP/#{to}", {}, ahn_call)
        # FIXME This doesn't work for repeatedly transferred calls:
        #
        metadata['current_dial'] = tdial
        execute_dial(tdial, call)
      ensure
        hangup
      end
    end
  end


  def execute_dial(dial, call)
    dial.run(self)
    update_second_leg(dial, call)
    dial.await_completion
    dial.cleanup_calls
  end


  def update_second_leg(dial, call)
    tcid = dial.status.calls.first.id
    Call.set_params_for(tcid, call)
  end


  def hangup
    if (call = find_ahn_call)
      call.pause_controllers
      call.hangup
    end
  end


  def find_ahn_call
    Adhearsion.active_calls[call_id]
  end
end
