require "rails_helper"

RSpec.describe "Api::V1::Inventory", type: :request do
  let(:shop) { create(:shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "POST /api/v1/inventory/sync" do
    it "enqueues an InventorySyncJob and returns accepted status" do
      expect {
        post "/api/v1/inventory/sync"
      }.to have_enqueued_job(InventorySyncJob).with(shop.id)

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("queued")
    end
  end
end
