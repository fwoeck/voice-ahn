class DirectContext < Adhearsion::CallController

  def run
    dial call.from, for: 15.seconds
  end
end
