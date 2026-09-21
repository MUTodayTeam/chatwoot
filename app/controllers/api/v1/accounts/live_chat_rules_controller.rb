class Api::V1::Accounts::LiveChatRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_live_chat_rule, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @live_chat_rules = Current.account.live_chat_rules
  end

  def show; end

  def create
    @live_chat_rule = Current.account.live_chat_rules.create!(live_chat_rule_params)
  end

  def update
    @live_chat_rule.update!(live_chat_rule_params)
  end

  def destroy
    @live_chat_rule.destroy!
    head :ok
  end

  private

  def fetch_live_chat_rule
    @live_chat_rule = Current.account.live_chat_rules.find(params[:id])
  end

  def live_chat_rule_params
    params.require(:live_chat_rule).permit(:project_id, :reply_timeout_minutes, :extension_minutes)
  end
end
