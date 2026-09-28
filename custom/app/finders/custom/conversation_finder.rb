module Custom::ConversationFinder
  # "All Chat": every conversation still being worked on.
  ACTIVE_STATUSES = %w[open pending snoozed].freeze

  private

  # Every conversation in the list shows its case number
  def conversations_base_query
    super.preload(case: :project)
  end

  def filter_by_status
    return super unless params[:status] == 'active'

    @conversations = @conversations.where(status: ACTIVE_STATUSES)
  end
end
