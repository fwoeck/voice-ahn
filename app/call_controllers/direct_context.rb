class DirectContext < Adhearsion::CallController

  def run
    dial call.from, from: call.to, for: 15.seconds
  end
end
