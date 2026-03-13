require "rails_helper"

RSpec.describe WebhookEndpoint, type: :model do
  let(:shop) { create(:shop) }

  describe "scopes" do
    describe ".active" do
      it "returns only active webhook endpoints" do
        ActsAsTenant.with_tenant(shop) do
          active_endpoint = create(:webhook_endpoint, shop: shop, is_active: true)
          inactive_endpoint = create(:webhook_endpoint, shop: shop, is_active: false)

          expect(WebhookEndpoint.active).to include(active_endpoint)
          expect(WebhookEndpoint.active).not_to include(inactive_endpoint)
        end
      end
    end
  end

  describe "tenant scoping" do
    it "automatically scopes to the current tenant" do
      endpoint = ActsAsTenant.with_tenant(shop) { create(:webhook_endpoint, shop: shop) }

      other_shop = create(:shop)
      other_endpoint = ActsAsTenant.with_tenant(other_shop) { create(:webhook_endpoint, shop: other_shop) }

      ActsAsTenant.with_tenant(shop) do
        expect(WebhookEndpoint.all).to include(endpoint)
        expect(WebhookEndpoint.all).not_to include(other_endpoint)
      end
    end
  end
end
