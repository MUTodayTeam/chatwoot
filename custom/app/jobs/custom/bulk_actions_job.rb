module Custom::BulkActionsJob
  # Assigning from the bulk bar goes through Conversations::AssignmentService, as assigning one
  # conversation does, so a conversation assigned to a bot opens for the agent it goes to (spec 7.4).
  def bulk_conversation_update
    fields = @params[:fields]&.to_h&.with_indifferent_access
    return super unless fields&.key?(:assignee_id)

    records.each do |conversation|
      Conversations::AssignmentService.new(conversation: conversation, assignee_id: fields[:assignee_id]).perform
    end
    @params = @params.merge(fields: fields.except(:assignee_id))
    super
  end
end
