require 'thread'
require 'timeout'

require './lib/call_handling'
require './lib/post_processing'
require './lib/menu_language'
require './lib/menu_skill'


QueueStruct = Struct.new(
  :queue, :language, :skill, :queued_at, :dispatched,
  :tries, :status, :agent, :moh, :call_id
)


class DefaultContext < Adhearsion::CallController
  include CallHandling
  include PostProcessing
  include MenuLanguage
  include MenuSkill

  attr_accessor :qs


  def run
    answer
    call.on_end { cleanup_leftovers }

    sleep 0.5
    play 'wimdu/en_welcome_to_wimdu'

    lang = choose_a_language
    Call.set_language_for(call_id, lang)

    skill = choose_a_skill(lang)
    Call.set_skill_for(call_id, skill)

    sleep 0.5
    play "wimdu/#{lang}_you_will_be_connected"

    Call.set_queued_at(call_id)
    queue_and_handle_call(lang, skill)
  end


  def call_id
    @call_id ||= call.id
  end
end
