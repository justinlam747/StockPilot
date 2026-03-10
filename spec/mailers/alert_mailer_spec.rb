require "rails_helper"

RSpec.describe AlertMailer, type: :mailer do
  let(:shop) { create(:shop, shop_domain: "test.myshopify.com") }
  let(:product) { create(:product, shop: shop, title: "Widget") }
  let(:variant) { create(:variant, shop: shop, product: product, sku: "WDG-001", title: "Small") }

  let(:flagged_variants) do
    [{ variant: variant, available: 3, on_hand: 5, status: :low_stock, threshold: 10 }]
  end

  describe "#low_stock" do
    let(:mail) { described_class.low_stock(shop, flagged_variants, "merchant@example.com") }

    it "renders the subject with shop domain and count" do
      expect(mail.subject).to include("test.myshopify.com")
      expect(mail.subject).to include("1")
    end

    it "sends to the correct email" do
      expect(mail.to).to eq(["merchant@example.com"])
    end

    it "includes variant details in the body" do
      expect(mail.body.encoded).to include("WDG-001")
      expect(mail.body.encoded).to include("Widget")
    end
  end
end
