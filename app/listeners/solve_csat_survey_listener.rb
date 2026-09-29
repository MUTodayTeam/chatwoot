# The stock CSAT listener, except for the resolve an agent solved with "send survey" unticked
class SolveCsatSurveyListener < CsatSurveyListener
  def conversation_status_changed(event)
    return if Conversations::SolveService.survey_skipped!(event.data[:conversation], event.timestamp)

    super
  end
end
