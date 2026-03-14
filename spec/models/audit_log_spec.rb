require "rails_helper"

RSpec.describe AuditLog, type: :model do
  let(:shop) { create(:shop) }

  it "records an event" do
    log = AuditLog.record(action: "login", shop: shop, metadata: { source: "oauth" })
    expect(log).to be_persisted
    expect(log.action).to eq("login")
    expect(log.shop).to eq(shop)
    expect(log.metadata["source"]).to eq("oauth")
  end

  it "is readonly once persisted" do
    log = AuditLog.record(action: "test", shop: shop)
    expect { log.update!(action: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "allows nil shop for unauthenticated events" do
    log = AuditLog.record(action: "login_failed", metadata: { reason: "invalid_shop" })
    expect(log).to be_persisted
    expect(log.shop).to be_nil
  end
end
