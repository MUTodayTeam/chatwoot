module Custom::AsyncDispatcher
  def listeners
    super + [CaseListener.instance]
  end
end
