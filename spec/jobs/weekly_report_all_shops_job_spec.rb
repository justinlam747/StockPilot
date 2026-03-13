require "rails_helper"

RSpec.describe WeeklyReportAllShopsJob, type: :job do
  let!(:shop_matching) do
    create(:shop, settings: {
      "timezone" => "America/Toronto",
      "weekly_report_day" => "monday"
    })
  end

  let!(:shop_wrong_day) do
    create(:shop, settings: {
      "timezone" => "America/Toronto",
      "weekly_report_day" => "friday"
    })
  end

  let!(:shop_uninstalled) do
    create(:shop, uninstalled_at: 1.day.ago, settings: {
      "timezone" => "America/Toronto",
      "weekly_report_day" => "monday"
    })
  end

  # Freeze time to Monday at 8 AM Toronto time
  around do |example|
    tz = ActiveSupport::TimeZone["America/Toronto"]
    # Find the next Monday at 8 AM in Toronto time
    now = tz.now
    monday = now.beginning_of_week(:monday).change(hour: 8)
    monday += 1.week if monday < now
    travel_to(monday.utc) { example.run }
  end

  it "enqueues WeeklyReportJob for shops matching day and hour" do
    expect { described_class.perform_now }
      .to have_enqueued_job(WeeklyReportJob).with(shop_matching.id)
  end

  it "does not enqueue for shops with wrong report day" do
    expect { described_class.perform_now }
      .not_to have_enqueued_job(WeeklyReportJob).with(shop_wrong_day.id)
  end

  it "does not enqueue for uninstalled shops" do
    expect { described_class.perform_now }
      .not_to have_enqueued_job(WeeklyReportJob).with(shop_uninstalled.id)
  end

  it "skips shops that already have a report for this week" do
    week_start = Time.current.beginning_of_week(:monday)
    create(:weekly_report, shop: shop_matching, week_start: week_start)

    expect { described_class.perform_now }
      .not_to have_enqueued_job(WeeklyReportJob).with(shop_matching.id)
  end

  context "when shop uses default report day (monday)" do
    let!(:shop_default_day) do
      create(:shop, settings: {
        "timezone" => "America/Toronto"
        # no weekly_report_day key — defaults to monday
      })
    end

    it "enqueues the job using the default monday" do
      expect { described_class.perform_now }
        .to have_enqueued_job(WeeklyReportJob).with(shop_default_day.id)
    end
  end
end
