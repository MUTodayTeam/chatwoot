module Custom::SyncDispatcher
  # Handler turns are recorded as the change commits, so each turn opens and closes in the
  # order the changes happened and knows who made them (Current.user).
  def listeners
    super + [ConversationHandlerListener.instance]
  end
end
