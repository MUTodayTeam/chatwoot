module Custom::Conversations::EventDataPresenter
  # The header's case chip follows the conversation over the websocket. A case is never
  # removed, so a conversation without one leaves the key out.
  def push_data
    kase = self.case
    kase ? super.merge(case: kase.push_event_data) : super
  end
end
