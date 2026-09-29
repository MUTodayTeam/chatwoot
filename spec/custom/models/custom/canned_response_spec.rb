require 'rails_helper'

RSpec.describe Custom::CannedResponse do
  let(:account) { create(:account) }
  let(:project) { account.projects.create!(name: 'Checkin+') }

  describe 'project validation' do
    it 'is shared by every project without one' do
      expect(build(:canned_response, account: account, project: nil)).to be_valid
    end

    it 'accepts a project of the same account' do
      expect(build(:canned_response, account: account, project: project)).to be_valid
    end

    it 'rejects a project of another account' do
      other_project = create(:account).projects.create!(name: 'Other')
      canned_response = build(:canned_response, account: account, project: other_project)

      expect(canned_response).not_to be_valid
      expect(canned_response.errors[:project]).to eq([I18n.t('errors.canned_responses.project_account_mismatch')])
    end

    it 'rejects a project that does not exist' do
      expect(build(:canned_response, account: account, project_id: 0)).not_to be_valid
    end
  end

  describe 'when the project is deleted' do
    let!(:canned_response) { create(:canned_response, account: account, project: project) }

    it 'keeps the response and shares it with every project' do
      project.destroy!

      expect(canned_response.reload.project_id).to be_nil
    end

    it 'shares the response with every project even when the deletion skips callbacks' do
      project.delete

      expect(canned_response.reload.project_id).to be_nil
    end

    it 'moves the canned response cache key so browsers refetch the list' do
      expect { travel(1.minute) { project.destroy! } }.to(change { account.cache_keys[:canned_response] })
    end
  end
end
