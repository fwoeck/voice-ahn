class AhnRpc

  attr_accessor :call_id, :command, :to, :from


  def handle_message
    self.send command
  end


  def sip_domain
    to.length > 4 ? "@#{AhnConfig['sip_proxy']}" : ''
  end


  def originate
    _from = "SIP/#{from}"
    _to   = "SIP/#{to}#{sip_domain}"

    Adhearsion::OutboundCall.originate(_from, from: _to) do
      opts = {for: AhnConfig.ring_timeout.seconds, from: _from}
      cd   = Adhearsion::CallController::Dial::Dial.new(_to, opts, call)
      metadata['current_dial'] = cd

      dial_outbound(cd, call)
    end
  end


  def dial_outbound(dial, ahn_call)
    dial.run(self)
    update_call_pair(dial, ahn_call)
    dial.await_completion
    dial.cleanup_calls
  end


  def update_call_pair(dial, ahn_call)
    oid  = dial.status.calls.first.id
    call = Call.find(oid).call

    Call.set_params_for(ahn_call.id, call)
    Call.set_caller_id_for(oid, ahn_call.from)
  end


  def transfer
    if (ahn_call = find_ahn_call)
      ahn_call.auto_hangup = false

      # FIXME Transfer of a call originated by us will fail, because
      #       a controller is needed to store the metadata:
      #
      return unless (ctrl = ahn_call.controllers.first)
      cdial = ctrl.metadata['current_dial']
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
    update_new_leg(dial, call)
    dial.await_completion
    dial.cleanup_calls
  end


  def update_new_leg(dial, call)
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
