require "rails_helper"

RSpec.describe Customer, type: :model do
  let(:shop) { create(:shop) }

  describe "tenant scoping" do
    it "automatically scopes to the current tenant" do
      customer = ActsAsTenant.with_tenant(shop) { create(:customer, shop: shop) }

      other_shop = create(:shop)
      other_customer = ActsAsTenant.with_tenant(other_shop) { create(:customer, shop: other_shop) }

      ActsAsTenant.with_tenant(shop) do
        expect(Customer.all).to include(customer)
        expect(Customer.all).not_to include(other_customer)
      end
    end
  end
end
