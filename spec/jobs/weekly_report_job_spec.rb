require "rails_helper"

RSpec.describe WeeklyReportJob, type: :job do
  let(:shop) { create(:shop, settings: { "timezone" => "America/Toronto", "alert_email" => "merchant@example.com" }) }

  let(:generator_payload) do
    { "top_sellers" => [{ "sku" => "ABC-1", "sold" => 42 }], "stockouts" => [], "low_sku_count" => 2 }
  end

  let(:weekly_generator) { instance_double(Reports::WeeklyGenerator) }
  let(:insights_generator) { instance_double(AI::InsightsGenerator) }

  before do
    allow(Reports::WeeklyGenerator).to receive(:new).and_return(weekly_generator)
    allow(weekly_generator).to receive(:generate).and_return(generator_payload)

    allow(AI::InsightsGenerator).to receive(:new).and_return(insights_generator)
    allow(insights_generator).to receive(:generate).and_return("AI commentary text")
  end

  it "creates a weekly report with the generated payload" do
    expect { described_class.perform_now(shop.id) }
      .to change(WeeklyReport, :count).by(1)

    report = WeeklyReport.last
    expect(report.shop).to eq(shop)
    expect(report.payload["top_sellers"]).to eq(generator_payload["top_sellers"])
  end

  it "includes AI commentary in the payload" do
    described_class.perform_now(shop.id)

    report = WeeklyReport.last
    expect(report.payload["ai_commentary"]).to eq("AI commentary text")
  end

  it "sends email when shop has alert_email" do
    expect { described_class.perform_now(shop.id) }
      .to have_enqueued_mail(ReportMailer, :weekly_summary)

    report = WeeklyReport.last
    expect(report.emailed_at).to be_present
  end

  it "does not send email when shop has no alert_email" do
    shop.update!(settings: shop.settings.merge("alert_email" => nil))

    expect { described_class.perform_now(shop.id) }
      .not_to have_enqueued_mail(ReportMailer, :weekly_summary)
  end

  it "does not send email twice for the same report" do
    described_class.perform_now(shop.id)
    report = WeeklyReport.last
    expect(report.emailed_at).to be_present

    # Running again should not send a second email because report already exists with emailed_at set
    expect { described_class.perform_now(shop.id) }
      .not_to have_enqueued_mail(ReportMailer, :weekly_summary)
  end

  context "when AI insights fail" do
    before do
      allow(insights_generator).to receive(:generate).and_raise(StandardError, "API down")
    end

    it "still saves the report without AI commentary" do
      expect { described_class.perform_now(shop.id) }
        .to change(WeeklyReport, :count).by(1)

      report = WeeklyReport.last
      expect(report.payload).not_to have_key("ai_commentary")
      expect(report.payload["top_sellers"]).to be_present
    end

    it "logs a warning" do
      allow(Rails.logger).to receive(:warn)

      described_class.perform_now(shop.id)

      expect(Rails.logger).to have_received(:warn).with(/AI insights failed.*API down/)
    end
  end

  context "when shop is inactive (uninstalled)" do
    before { shop.update!(uninstalled_at: 1.day.ago) }

    it "raises ActiveRecord::RecordNotFound" do
      expect { described_class.perform_now(shop.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
