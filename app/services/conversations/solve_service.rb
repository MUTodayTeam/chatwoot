# Solved from the Select Category dialog (spec 7.3). The conversation is resolved the stock way,
# so events, CSAT and reports treat it like any other resolve; its case is then filed under the
# chosen category (none is "Other") with the solver as resolved_by, and the timeline says when
# the rule will close it.
class Conversations::SolveService
  # CSAT goes out from an async listener, so skipping it for this one resolve is a flag that
  # listener consumes. It outlives any sane queue delay and is cleared if the resolve fails.
  SURVEY_SKIPPED_KEY = 'CONVERSATION::%<id>d::SURVEY_SKIPPED'.freeze
  SURVEY_SKIPPED_TTL = 1.day

  pattr_initialize [:conversation!, :user!, :case_category, :summary, :send_survey!]

  # Whether the resolve being handled was solved without a survey; true only once
  def self.survey_skipped!(conversation)
    Redis::Alfred.delete(survey_skipped_key(conversation)).positive?
  end

  def self.survey_skipped_key(conversation)
    format(SURVEY_SKIPPED_KEY, id: conversation.id)
  end

  def perform
    skip_survey unless send_survey
    kase = resolve_and_file
    create_solved_activity
    kase
  end

  private

  def resolve_and_file
    ActiveRecord::Base.transaction do
      conversation.update!(status: :resolved)
      # A conversation solved before anyone took it gets its case now
      kase = Case.ensure_for!(conversation, user)
      kase.update!(case_category: case_category, resolved_by: user, summary: summary.presence)
      kase
    end
  rescue StandardError
    # Nothing was resolved, so the next resolve sends its survey as usual
    Redis::Alfred.delete(self.class.survey_skipped_key(conversation)) unless send_survey
    raise
  end

  def skip_survey
    Redis::Alfred.setex(self.class.survey_skipped_key(conversation), true, SURVEY_SKIPPED_TTL)
  end

  # Queued like the stock "resolved by" activity, so it lands after it
  def create_solved_activity
    account = conversation.account
    topic = case_category&.c3 || I18n.t('conversations.activity.solved_other_topic', locale: account.locale)
    content = I18n.t('conversations.activity.solved', topic: topic, count: conversation.live_chat_rule.auto_close_hours, locale: account.locale)
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      { account_id: conversation.account_id, inbox_id: conversation.inbox_id, message_type: :activity, content: content }
    )
  end
end
