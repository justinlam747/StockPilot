require "rails_helper"

RSpec.describe "Api::V1::PurchaseOrders", type: :request do
  let(:shop) { create(:shop) }
  let(:supplier) { create(:supplier, shop: shop) }

  before do
    authenticate_shop(shop)
    ActsAsTenant.current_tenant = shop
  end

  describe "GET /api/v1/purchase_orders" do
    it "returns paginated purchase orders with supplier and line items" do
      create(:purchase_order, shop: shop, supplier: supplier)

      get "/api/v1/purchase_orders"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["purchase_orders"].size).to eq(1)
      expect(body["meta"]).to include("current_page", "total_pages", "total_count", "per_page")
    end

    it "does not return purchase orders from another shop" do
      other_shop = create(:shop)
      other_supplier = create(:supplier, shop: other_shop)
      ActsAsTenant.with_tenant(other_shop) do
        create(:purchase_order, shop: other_shop, supplier: other_supplier)
      end

      get "/api/v1/purchase_orders"

      body = JSON.parse(response.body)
      expect(body["purchase_orders"].size).to eq(0)
    end
  end

  describe "GET /api/v1/purchase_orders/:id" do
    it "returns a single purchase order with associations" do
      po = create(:purchase_order, shop: shop, supplier: supplier)

      get "/api/v1/purchase_orders/#{po.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(po.id)
      expect(body["supplier"]).to be_present
    end
  end

  describe "POST /api/v1/purchase_orders" do
    it "creates a purchase order" do
      params = {
        purchase_order: {
          supplier_id: supplier.id,
          status: "draft",
          order_date: Date.current.to_s,
          expected_delivery: (Date.current + 14.days).to_s,
          notes: "Test order"
        }
      }

      post "/api/v1/purchase_orders",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("draft")
      expect(body["notes"]).to eq("Test order")
      expect(PurchaseOrder.count).to eq(1)
    end

    it "creates a purchase order with nested line items" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      params = {
        purchase_order: {
          supplier_id: supplier.id,
          status: "draft",
          order_date: Date.current.to_s,
          expected_delivery: (Date.current + 14.days).to_s,
          line_items_attributes: [
            { variant_id: variant.id, sku: variant.sku, quantity_ordered: 50, unit_price: 9.99 }
          ]
        }
      }

      post "/api/v1/purchase_orders",
           params: params.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["line_items"].size).to eq(1)
    end
  end

  describe "PATCH /api/v1/purchase_orders/:id" do
    it "updates a purchase order" do
      po = create(:purchase_order, shop: shop, supplier: supplier, notes: "Old notes")

      patch "/api/v1/purchase_orders/#{po.id}",
            params: { purchase_order: { notes: "Updated notes" } }.to_json,
            headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(po.reload.notes).to eq("Updated notes")
    end
  end

  describe "DELETE /api/v1/purchase_orders/:id" do
    it "destroys a purchase order" do
      po = create(:purchase_order, shop: shop, supplier: supplier)

      delete "/api/v1/purchase_orders/#{po.id}"

      expect(response).to have_http_status(:no_content)
      expect(PurchaseOrder.find_by(id: po.id)).to be_nil
    end
  end

  describe "POST /api/v1/purchase_orders/generate_draft" do
    let(:product) { create(:product, shop: shop) }
    let(:variant) { create(:variant, shop: shop, product: product, supplier: supplier, price: 19.99, sku: "TEST-SKU") }

    let(:low_stock_results) do
      [{ variant: variant, threshold: 10, available: 3 }]
    end

    before do
      detector = instance_double(Inventory::LowStockDetector, detect: low_stock_results)
      allow(Inventory::LowStockDetector).to receive(:new).and_return(detector)
    end

    it "creates a draft PO with line items from low stock detection" do
      generator = instance_double(AI::PoDraftGenerator, generate: "Dear supplier, please ship...")
      allow(AI::PoDraftGenerator).to receive(:new).and_return(generator)

      post "/api/v1/purchase_orders/generate_draft",
           params: { supplier_id: supplier.id }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("draft")
      expect(body["line_items"].size).to eq(1)
      expect(PurchaseOrder.last.draft_body).to eq("Dear supplier, please ship...")
    end

    it "still creates the PO when AI draft generation fails" do
      allow(AI::PoDraftGenerator).to receive(:new).and_raise(StandardError, "API timeout")

      post "/api/v1/purchase_orders/generate_draft",
           params: { supplier_id: supplier.id }.to_json,
           headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("draft")
      expect(PurchaseOrder.last.draft_body).to be_nil
    end
  end

  describe "POST /api/v1/purchase_orders/:id/send_email" do
    it "delivers the PO email and updates status to sent" do
      po = create(:purchase_order, shop: shop, supplier: supplier, status: "draft")

      mailer_double = double("mailer", deliver_later: true)
      allow(PurchaseOrderMailer).to receive(:send_po).with(po).and_return(mailer_double)

      post "/api/v1/purchase_orders/#{po.id}/send_email"

      expect(response).to have_http_status(:ok)
      expect(PurchaseOrderMailer).to have_received(:send_po).with(po)
      expect(mailer_double).to have_received(:deliver_later)

      po.reload
      expect(po.status).to eq("sent")
      expect(po.sent_at).to be_present
    end
  end
end
