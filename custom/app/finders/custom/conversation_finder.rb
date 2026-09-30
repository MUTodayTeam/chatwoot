module Custom::ConversationFinder
  # "All Chat": every conversation still being worked on.
  ACTIVE_STATUSES = %w[open pending snoozed].freeze

  private

  # Every conversation in the list shows its case number and topic
  def conversations_base_query
    super.preload(case: [:project, :case_category])
  end

  # "Missed" is a flag the sweep sets, not a status, so it lists missed conversations in any status
  def filter_by_status
    case params[:status]
    when 'active' then @conversations = @conversations.where(status: ACTIVE_STATUSES)
    when 'missed' then @conversations = @conversations.where.not(missed_at: nil)
    else super
    end
  end
end
