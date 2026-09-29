# The stock CSAT listener, except for the resolve an agent solved with "send survey" unticked
class SolveCsatSurveyListener < CsatSurveyListener
  def conversation_status_changed(event)
    conversation = event.data[:conversation]
    return if conversation.resolved? && Conversations::SolveService.survey_skipped!(conversation)

    super
  end
end
