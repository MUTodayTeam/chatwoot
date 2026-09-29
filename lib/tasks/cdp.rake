namespace :cdp do
  desc 'Create the Type and Partner ID contact attributes. Options: ACCOUNT_ID (every account when left out)'
  task seed_contact_attributes: :environment do
    accounts = ENV['ACCOUNT_ID'].present? ? [Account.find(ENV.fetch('ACCOUNT_ID'))] : Account.find_each
    accounts.each { |account| Contacts::CdpAttributesSeeder.new(account).perform }
  end
end
