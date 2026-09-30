module Custom::SyncDispatcher
  # Handler turns are recorded as the change commits, so each turn opens and closes in the
  # order the changes happened and knows who made them (Current.user). A resolve files its
  # case the same way, so it knows who resolved it.
  def listeners
    super + [ConversationHandlerListener.instance, CaseResolvedListener.instance]
  end
end
