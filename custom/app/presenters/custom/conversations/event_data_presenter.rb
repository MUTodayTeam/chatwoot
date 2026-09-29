module Custom::Conversations::EventDataPresenter
  # The header's case chip follows the conversation over the websocket. A case is never
  # removed, so a conversation without one leaves the key out. The end-of-chat bar's
  # auto-close countdown restarts from status_changed_at on every status change.
  def push_data
    data = super.merge(status_changed_at: status_changed_at.to_i)
    kase = self.case
    kase ? data.merge(case: kase.push_event_data) : data
  end
end
