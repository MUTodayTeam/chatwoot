module Custom::AsyncDispatcher
  def listeners
    super.map { |listener| listener == CsatSurveyListener.instance ? SolveCsatSurveyListener.instance : listener } + [CaseListener.instance]
  end
end
