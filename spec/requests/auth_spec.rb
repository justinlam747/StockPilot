require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "GET /auth/shopify/callback" do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: "shopify",
        uid: "test-shop.myshopify.com",
        credentials: { token: "test-token" },
        extra: { raw_info: { myshopify_domain: "test-shop.myshopify.com", name: "Test Shop" } }
      )
    end

    before do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:shopify] = auth_hash
    end

    after { OmniAuth.config.test_mode = false }

    it "creates a shop and redirects to dashboard" do
      expect {
        get "/auth/shopify/callback"
      }.to change(Shop, :count).by(1)
      expect(response).to redirect_to("/dashboard")
    end

    it "creates an audit log entry" do
      expect {
        get "/auth/shopify/callback"
      }.to change(AuditLog.where(action: "login"), :count).by(1)
    end

    it "prevents session fixation by resetting session" do
      get "/auth/shopify/callback"
      get "/auth/shopify/callback"
      expect(response).to redirect_to("/dashboard")
    end
  end

  describe "DELETE /logout" do
    let(:shop) { create(:shop) }

    it "destroys session and redirects to root" do
      login_as(shop)
      delete "/logout"
      expect(response).to redirect_to("/")
    end
  end
end
