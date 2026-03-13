require "rails_helper"

RSpec.describe Agents::Runner do
  describe ".run_all_shops" do
    let!(:active_shop_1) { create(:shop, shop_domain: "active-1.myshopify.com") }
    let!(:active_shop_2) { create(:shop, shop_domain: "active-2.myshopify.com") }
    let!(:uninstalled_shop) { create(:shop, shop_domain: "gone.myshopify.com", uninstalled_at: 1.day.ago) }

    let(:mock_monitor_1) { instance_double(Agents::InventoryMonitor) }
    let(:mock_monitor_2) { instance_double(Agents::InventoryMonitor) }

    before do
      allow(Agents::InventoryMonitor).to receive(:new).with(active_shop_1).and_return(mock_monitor_1)
      allow(Agents::InventoryMonitor).to receive(:new).with(active_shop_2).and_return(mock_monitor_2)
      allow(mock_monitor_1).to receive(:run).and_return({ log: ["done"], turns: 2 })
      allow(mock_monitor_2).to receive(:run).and_return({ log: ["done"], turns: 1 })
    end

    it "runs InventoryMonitor for each active shop" do
      described_class.run_all_shops

      expect(mock_monitor_1).to have_received(:run).once
      expect(mock_monitor_2).to have_received(:run).once
    end

    it "does not run for uninstalled shops" do
      expect(Agents::InventoryMonitor).not_to receive(:new).with(uninstalled_shop)

      described_class.run_all_shops
    end

    it "wraps each shop in ActsAsTenant.with_tenant" do
      tenants_used = []
      allow(ActsAsTenant).to receive(:with_tenant).and_wrap_original do |method, shop, &block|
        tenants_used << shop
        method.call(shop, &block)
      end

      described_class.run_all_shops

      expect(tenants_used).to contain_exactly(active_shop_1, active_shop_2)
    end

    it "returns results for each shop" do
      results = described_class.run_all_shops

      expect(results.size).to eq(2)
      expect(results.map { |r| r[:shop] }).to contain_exactly(
        "active-1.myshopify.com",
        "active-2.myshopify.com"
      )
    end

    context "when one shop raises an error" do
      before do
        allow(mock_monitor_1).to receive(:run).and_raise(StandardError.new("shop 1 broke"))
      end

      it "logs the error and continues to the next shop" do
        expect(Rails.logger).to receive(:error).with(/Error for active-1.myshopify.com/)

        results = described_class.run_all_shops

        # Shop 2 should still have run
        expect(mock_monitor_2).to have_received(:run).once
      end

      it "includes the error in the results" do
        allow(Rails.logger).to receive(:error)

        results = described_class.run_all_shops

        errored = results.find { |r| r[:shop] == "active-1.myshopify.com" }
        expect(errored[:error]).to eq("shop 1 broke")
      end

      it "still returns a result for the successful shop" do
        allow(Rails.logger).to receive(:error)

        results = described_class.run_all_shops

        successful = results.find { |r| r[:shop] == "active-2.myshopify.com" }
        expect(successful[:turns]).to eq(1)
      end
    end
  end

  describe ".run_for_shop" do
    let!(:active_shop) { create(:shop) }
    let(:mock_monitor) { instance_double(Agents::InventoryMonitor) }

    before do
      allow(Agents::InventoryMonitor).to receive(:new).with(active_shop).and_return(mock_monitor)
      allow(mock_monitor).to receive(:run).and_return({ log: ["done"], turns: 3 })
    end

    it "finds the shop by ID and runs the monitor" do
      result = described_class.run_for_shop(active_shop.id)

      expect(mock_monitor).to have_received(:run).once
      expect(result[:turns]).to eq(3)
    end

    it "wraps execution in ActsAsTenant.with_tenant" do
      tenant_used = nil
      allow(ActsAsTenant).to receive(:with_tenant).and_wrap_original do |method, shop, &block|
        tenant_used = shop
        method.call(shop, &block)
      end

      described_class.run_for_shop(active_shop.id)

      expect(tenant_used).to eq(active_shop)
    end

    it "raises ActiveRecord::RecordNotFound for nonexistent shop" do
      expect {
        described_class.run_for_shop(999_999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises ActiveRecord::RecordNotFound for uninstalled shop" do
      uninstalled = create(:shop, uninstalled_at: 1.day.ago)

      expect {
        described_class.run_for_shop(uninstalled.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
