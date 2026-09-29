module Custom::MessageFinder
  # The conversation timeline reads what happened to a conversation from its activity
  # messages across its whole history, not from the page of the thread the agent has loaded.
  ACTIVITY_LIMIT = 200

  private

  def current_messages
    return super if @params[:activity_only].blank?

    messages.activity.reorder(created_at: :desc, id: :desc).limit(ACTIVITY_LIMIT).reverse
  end
end
