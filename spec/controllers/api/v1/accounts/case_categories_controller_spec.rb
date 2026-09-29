require 'rails_helper'

RSpec.describe 'Case Categories API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base_path) { "/api/v1/accounts/#{account.id}/case_categories" }
  let!(:booking) do
    create(:case_category, account: account, inquiry_type: :problem, c1: 'Booking', c2: 'Overbooking', c3: 'Same room',
                           sla_respond_minutes: 15, sla_resolve_minutes: 240)
  end
  let!(:greeting) { create(:case_category, account: account, inquiry_type: :info, c1: 'ทั่วไป', c2: 'ทักทาย', c3: 'Greeting') }

  before { create(:case_category, c1: 'Booking', c3: 'Another account') }

  describe 'GET /api/v1/accounts/{account.id}/case_categories' do
    it 'returns unauthorized without a user' do
      get base_path

      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the account's categories to an agent" do
      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      payload = response.parsed_body['payload']
      expect(payload.pluck('id')).to contain_exactly(booking.id, greeting.id)
      expect(payload.find { |category| category['id'] == booking.id }).to eq(
        'id' => booking.id, 'inquiry_type' => 'problem', 'c1' => 'Booking', 'c2' => 'Overbooking', 'c3' => 'Same room',
        'sla_respond_minutes' => 15, 'sla_resolve_minutes' => 240
      )
    end

    it 'searches any level and filters by inquiry type' do
      get base_path, params: { q: 'ทักทาย' }, headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('id')).to eq([greeting.id])

      get base_path, params: { q: 'room' }, headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('id')).to eq([booking.id])

      get base_path, params: { inquiry_type: 'info' }, headers: agent.create_new_auth_token
      expect(response.parsed_body['payload'].pluck('id')).to eq([greeting.id])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/case_categories' do
    let(:params) { { case_category: { inquiry_type: 'request', c1: 'คำสั่งซื้อ', c2: '', c3: 'ขอยกเลิก', sla_respond_minutes: 15 } } }

    it 'is refused to an agent' do
      post base_path, params: params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a category for an administrator' do
      post base_path, params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('c1' => 'คำสั่งซื้อ', 'c3' => 'ขอยกเลิก', 'inquiry_type' => 'request', 'sla_respond_minutes' => 15)
      expect(CaseCategory.find(response.parsed_body['id']).account_id).to eq(account.id)
    end

    it 'refuses a path that already exists' do
      post base_path, params: { case_category: { c1: 'booking', c2: 'overbooking', c3: 'SAME ROOM' } },
                      headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH and DELETE /api/v1/accounts/{account.id}/case_categories/{id}' do
    it 'are refused to an agent' do
      patch "#{base_path}/#{booking.id}", params: { case_category: { c3: 'Renamed' } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{base_path}/#{booking.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(booking.reload.c3).to eq('Same room')
    end

    it 'update and delete for an administrator, leaving its cases as Other' do
      kase = create(:case, conversation: create(:conversation, account: account), case_category: booking)

      patch "#{base_path}/#{booking.id}", params: { case_category: { c3: 'Renamed', sla_resolve_minutes: nil } },
                                          headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('c3' => 'Renamed', 'sla_resolve_minutes' => nil)
      expect(booking.reload.merge_key).to eq('booking|overbooking|renamed')

      delete "#{base_path}/#{booking.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(CaseCategory.exists?(booking.id)).to be(false)
      expect(kase.reload.case_category_id).to be_nil
    end

    it "cannot reach another account's category" do
      other = CaseCategory.find_by!(c3: 'Another account')

      delete "#{base_path}/#{other.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET template.csv and export.csv' do
    it 'are refused to an agent' do
      get "#{base_path}/template.csv", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)

      get "#{base_path}/export.csv", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)
    end

    it 'download as UTF-8 CSV with a BOM for an administrator' do
      get "#{base_path}/template.csv", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.body.force_encoding('UTF-8')).to eq(CaseCategories::CsvService.template)

      get "#{base_path}/export.csv", headers: admin.create_new_auth_token

      body = response.body.force_encoding('UTF-8')
      expect(body).to start_with("\uFEFF")
      expect(CSV.parse(body.delete_prefix("\uFEFF")).drop(1)).to contain_exactly(
        ['Booking', 'Overbooking', 'Same room', '15 นาที / 4 ชม.', 'Problem'], ['ทั่วไป', 'ทักทาย', 'Greeting', '15 นาที / 1 วัน', 'Info']
      )
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/case_categories/import' do
    let(:csv) do
      "\uFEFFCategory 1,Category 2,Category 3,SLA,Inquiry Type\n" \
        "Booking,Overbooking,Same room,1 วัน,\n" \
        "คำสั่งซื้อ,,ขอยกเลิก,15 นาที / 4 ชม.,Request\n" \
        "คำสั่งซื้อ,,,,\n"
    end
    let(:file) { Rack::Test::UploadedFile.new(StringIO.new(csv), 'text/csv', original_filename: 'categories.csv') }

    it 'is refused to an agent' do
      post "#{base_path}/import", params: { file: file }, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unauthorized)
    end

    it 'merges the file and returns what it added, skipped and could not read' do
      post "#{base_path}/import", params: { file: file }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['added'].pluck('c1', 'c3', 'sla_resolve_minutes')).to eq([['คำสั่งซื้อ', 'ขอยกเลิก', 240]])
      expect(body['skipped']).to eq(1)
      expect(body['invalid']).to eq([{ 'line' => 4, 'values' => ['คำสั่งซื้อ', '', '', '', ''], 'reason' => 'missing_category' }])
      expect(booking.reload.sla_resolve_minutes).to eq(240)
    end

    it 'reports a file it cannot parse, or no file' do
      broken = Rack::Test::UploadedFile.new(StringIO.new("a,\"b\n"), 'text/csv', original_filename: 'broken.csv')
      post "#{base_path}/import", params: { file: broken }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)

      post "#{base_path}/import", params: { file: 'not a file' }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
