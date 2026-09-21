class NotificationFinder
  attr_reader :current_user, :current_account, :params

  RESULTS_PER_PAGE = 15

  def initialize(current_user, current_account, params = {})
    @current_user = current_user
    @current_account = current_account
    @params = params
    set_up
  end

  def notifications
    @notifications.page(current_page).per(RESULTS_PER_PAGE).order(last_activity_at: sort_order)
  end

  def unread_count
    if type_included?('read')
      # If we're including read notifications, filter to unread
      @notifications.where(read_at: nil).count
    else
      # Already filtered to unread notifications, just count
      @notifications.count
    end
  end

  def count
    @notifications.count
  end

  private

  def set_up
    find_all_notifications
    filter_by_assigned_conversations
    filter_snoozed_notifications
    filter_read_notifications
  end

  def find_all_notifications
    @notifications = current_user.notifications.where(account_id: @current_account.id)
  end

  # My Inbox is the agent's own worklist, so it carries only the conversations
  # currently assigned to them. Applying it here rather than in the controller
  # keeps the list, the unread badge and the total counting the same rows.
  # Every notification type points at a conversation, so nothing else is dropped.
  def filter_by_assigned_conversations
    @notifications = @notifications.where(
      primary_actor_type: 'Conversation',
      primary_actor_id: current_account.conversations.where(assignee_id: current_user.id).select(:id)
    )
  end

  def filter_snoozed_notifications
    @notifications = @notifications.where(snoozed_until: nil) unless type_included?('snoozed')
  end

  def filter_read_notifications
    @notifications = @notifications.where(read_at: nil) unless type_included?('read')
  end

  def type_included?(type)
    (params[:includes] || []).include?(type)
  end

  def current_page
    params[:page] || 1
  end

  def sort_order
    params[:sort_order] || :desc
  end
end
