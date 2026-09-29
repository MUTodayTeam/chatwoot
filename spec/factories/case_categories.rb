# frozen_string_literal: true

FactoryBot.define do
  factory :case_category do
    account
    inquiry_type { :request }
    c1 { 'คำสั่งซื้อ' }
    c2 { 'สถานะคำสั่งซื้อ' }
    sequence(:c3) { |n| "ติดตามสถานะคำสั่งซื้อ #{n}" }
    sla_respond_minutes { 15 }
    sla_resolve_minutes { 1440 }
  end
end
