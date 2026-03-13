require "rails_helper"

RSpec.describe AgentInventoryCheckJob, type: :job do
  before do
    allow(Agents::Runner).to receive(:run_for_shop)
    allow(Agents::Runner).to receive(:run_all_shops)
  end

  describe "with a specific shop_id" do
    it "delegates to Agents::Runner.run_for_shop" do
      described_class.perform_now(42)

      expect(Agents::Runner).to have_received(:run_for_shop).with(42)
      expect(Agents::Runner).not_to have_received(:run_all_shops)
    end
  end

  describe "without a shop_id" do
    it "delegates to Agents::Runner.run_all_shops" do
      described_class.perform_now

      expect(Agents::Runner).to have_received(:run_all_shops)
      expect(Agents::Runner).not_to have_received(:run_for_shop)
    end
  end

  describe "queue" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
