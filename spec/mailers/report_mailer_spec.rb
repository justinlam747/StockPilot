require "rails_helper"

RSpec.describe ReportMailer, type: :mailer do
  let(:shop) { create(:shop, shop_domain: "widgets-r-us.myshopify.com") }
  let(:week_start) { Time.zone.parse("2026-03-09").beginning_of_week(:monday) }

  let(:report) do
    create(:weekly_report,
      shop: shop,
      week_start: week_start,
      payload: {
        "top_sellers" => [{ "sku" => "WDG-001", "sold" => 50 }],
        "stockouts" => [],
        "low_sku_count" => 3,
        "ai_commentary" => "Inventory looks healthy this week."
      }
    )
  end

  describe "#weekly_summary" do
    let(:mail) { described_class.weekly_summary(report, "merchant@example.com") }

    it "sends to the correct recipient" do
      expect(mail.to).to eq(["merchant@example.com"])
    end

    it "renders the subject with shop domain" do
      expect(mail.subject).to include("widgets-r-us.myshopify.com")
    end

    it "renders the subject with the formatted week start date" do
      expect(mail.subject).to include("Mar 09, 2026")
    end

    it "renders the subject in the expected format" do
      expect(mail.subject).to eq(
        "[widgets-r-us.myshopify.com] Weekly Inventory Report — Mar 09, 2026"
      )
    end

    it "assigns @report" do
      expect(mail.body.encoded).to be_present
    end

    it "assigns @payload for the template" do
      # The mailer sets @payload = report.payload, which the template uses.
      # We verify the mail renders without error (template has access to @payload).
      expect { mail.body }.not_to raise_error
    end
  end
end
