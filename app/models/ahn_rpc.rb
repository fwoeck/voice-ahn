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
      opts = {for: DialTimeout.seconds}
      cd   = Adhearsion::CallController::Dial::Dial.new(_to, opts, call)
      metadata['current_dial'] = cd

      dial_outbound(cd, call)
    end
  end


  def dial_outbound(dial, ahn_call)
    dial.run(self)
    update_first_leg(dial, ahn_call)
    dial.await_completion
    dial.cleanup_calls
  end


  # FIXME This sets the outbound call originId on the agent's
  #       call leg to provide these details to the services
  #       downstream.
  #       It depends on dial.status.calls.first, which
  #       seems brittle.
  #
  def update_first_leg(dial, ahn_call)
    oid = dial.status.calls.first.id
    Call.set_params_for ahn_call.id, Call.find(oid).call
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
    update_second_leg(dial, call)
    dial.await_completion
    dial.cleanup_calls
  end


  # FIXME This sets the current call originId on the 2nd agent's
  #       call leg to provide these details to the services
  #       downstream.
  #       It depends on dial.status.calls.first, which
  #       seems brittle.
  #
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
