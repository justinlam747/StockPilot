require "rails_helper"

RSpec.describe "Purchase Orders", type: :request do
  let(:shop) { create(:shop) }
  let!(:supplier) { create(:supplier) }

  before { login_as(shop) }

  describe "GET /purchase_orders" do
    it "returns success" do
      get "/purchase_orders"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /purchase_orders/:id" do
    let!(:po) { create(:purchase_order, supplier: supplier) }

    it "returns success" do
      get "/purchase_orders/#{po.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /purchase_orders/:id/mark_sent" do
    let!(:po) { create(:purchase_order, supplier: supplier, status: "draft") }

    it "updates status to sent" do
      patch "/purchase_orders/#{po.id}/mark_sent"
      expect(po.reload.status).to eq("sent")
    end
  end

  describe "PATCH /purchase_orders/:id/mark_received" do
    let!(:po) { create(:purchase_order, supplier: supplier, status: "sent") }

    it "updates status to received" do
      patch "/purchase_orders/#{po.id}/mark_received"
      expect(po.reload.status).to eq("received")
    end
  end

  describe "POST /purchase_orders/generate_draft" do
    it "creates an audit log" do
      allow(AI::PoDraftGenerator).to receive(:new).and_return(double(call: { draft: "test" }))
      expect {
        post "/purchase_orders/generate_draft"
      }.to change(AuditLog.where(action: "po_draft_generated"), :count).by(1)
    end
  end
end
