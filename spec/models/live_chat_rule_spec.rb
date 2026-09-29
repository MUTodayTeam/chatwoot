require 'rails_helper'

RSpec.describe LiveChatRule do
  let(:account) { create(:account) }

  it 'accepts hours and minutes up to a year' do
    rule = account.live_chat_rules.new(auto_solve_hours: 8_760, auto_close_hours: 8_760, waiting_time_minutes: 525_600)

    expect(rule).to be_valid
  end

  it 'rejects hours and minutes past a year' do
    rule = account.live_chat_rules.new(auto_close_hours: 8_761, waiting_time_minutes: 525_601)

    expect(rule).not_to be_valid
    expect(rule.errors.attribute_names).to contain_exactly(:auto_close_hours, :waiting_time_minutes)
  end

  it 'rejects a transfer team that does not exist' do
    rule = account.live_chat_rules.new(transfer_team_id: 999_999)

    expect(rule).not_to be_valid
    expect(rule.errors.attribute_names).to eq([:transfer_team_id])
  end

  it 'rejects a transfer team from another account' do
    rule = account.live_chat_rules.new(transfer_team: create(:team))

    expect(rule).not_to be_valid
  end

  it 'clears the transfer team when the team is deleted' do
    team = create(:team, account: account)
    rule = account.live_chat_rules.create!(transfer_team: team)

    team.destroy!

    expect(rule.reload.transfer_team_id).to be_nil
  end

  it 'lets the database hold only one default rule per account' do
    account.live_chat_rules.create!(project_id: nil)

    expect { account.live_chat_rules.new(project_id: nil).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
