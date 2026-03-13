require "rails_helper"

RSpec.describe WeeklyReport, type: :model do
  let(:shop) { create(:shop) }

  describe "tenant scoping" do
    it "automatically scopes to the current tenant" do
      report = ActsAsTenant.with_tenant(shop) { create(:weekly_report, shop: shop) }

      other_shop = create(:shop)
      other_report = ActsAsTenant.with_tenant(other_shop) { create(:weekly_report, shop: other_shop) }

      ActsAsTenant.with_tenant(shop) do
        expect(WeeklyReport.all).to include(report)
        expect(WeeklyReport.all).not_to include(other_report)
      end
    end
  end
end
