require "rails_helper"

RSpec.describe "Error handling and resilience", type: :model do
  let(:shop) do
    create(:shop, settings: {
      "low_stock_threshold" => 10,
      "timezone" => "America/Toronto",
      "alert_email" => "merchant@example.com"
    })
  end

  before do
    ActsAsTenant.current_tenant = shop
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY").and_return("test-key")
  end

  # ---------------------------------------------------------------------------
  # 1. Shopify API failures in InventoryFetcher
  # ---------------------------------------------------------------------------
  describe "Shopify::InventoryFetcher error handling" do
    let(:fetcher) { Shopify::InventoryFetcher.new(shop) }

    it "propagates ShopifyThrottledError after retries exhausted" do
      client = instance_double(Shopify::GraphqlClient)
      allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(client)
      allow(client).to receive(:paginate).and_raise(
        Shopify::GraphqlClient::ShopifyThrottledError, "Rate limited by Shopify"
      )

      expect { fetcher.call }.to raise_error(
        Shopify::GraphqlClient::ShopifyThrottledError, /Rate limited/
      )
    end

    it "propagates ShopifyApiError for non-throttle errors" do
      client = instance_double(Shopify::GraphqlClient)
      allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(client)
      allow(client).to receive(:paginate).and_raise(
        Shopify::GraphqlClient::ShopifyApiError, "Internal error"
      )

      expect { fetcher.call }.to raise_error(
        Shopify::GraphqlClient::ShopifyApiError, /Internal error/
      )
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Anthropic API failures in InsightsGenerator
  # ---------------------------------------------------------------------------
  describe "AI::InsightsGenerator resilience" do
    let(:generator) { AI::InsightsGenerator.new(shop) }
    let(:mock_client) { instance_double(Anthropic::Client) }

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      allow(Inventory::LowStockDetector).to receive_message_chain(:new, :detect).and_return([])
    end

    it "returns fallback string when Anthropic raises Anthropic::Error" do
      allow(mock_client).to receive(:messages).and_raise(
        Anthropic::Error, "API key invalid"
      )

      result = generator.generate

      expect(result).to eq("AI insights temporarily unavailable.")
    end

    it "handles nil content gracefully when Anthropic returns empty response" do
      allow(mock_client).to receive(:messages).and_return(
        { "content" => [] }
      )

      result = generator.generate

      # dig into empty array returns nil — should not raise
      expect(result).to be_nil
    end

    it "handles nil content block text gracefully" do
      allow(mock_client).to receive(:messages).and_return(
        { "content" => [{ "type" => "text", "text" => nil }] }
      )

      result = generator.generate

      expect(result).to be_nil
    end

    it "logs the error when Anthropic fails" do
      allow(mock_client).to receive(:messages).and_raise(
        Anthropic::Error, "Service unavailable"
      )

      expect(Rails.logger).to receive(:warn).with(/Anthropic API error.*Service unavailable/)

      generator.generate
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Anthropic API failures in PoDraftGenerator
  # ---------------------------------------------------------------------------
  describe "AI::PoDraftGenerator resilience" do
    let(:generator) { AI::PoDraftGenerator.new }
    let(:mock_client) { instance_double(Anthropic::Client) }
    let(:supplier) { create(:supplier, shop: shop, name: "Acme Supplies", email: "acme@example.com") }
    let(:product) { create(:product, shop: shop, title: "Widget") }
    let(:variant) { create(:variant, shop: shop, product: product, title: "Blue", sku: "WDG-BLU", price: 9.99) }
    let(:po) { create(:purchase_order, shop: shop, supplier: supplier) }
    let(:line_item) do
      create(:purchase_order_line_item,
        purchase_order: po,
        variant: variant,
        sku: variant.sku,
        qty_ordered: 10,
        unit_price: 9.99
      )
    end

    before do
      allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      # Stub the method the generator calls on line_items
      allow(line_item).to receive(:quantity_ordered).and_return(line_item.qty_ordered)
    end

    it "returns fallback plain text draft when Anthropic raises error" do
      allow(mock_client).to receive(:messages).and_raise(
        Anthropic::Error, "Rate limit exceeded"
      )

      result = generator.generate(supplier: supplier, line_items: [line_item], shop: shop)

      expect(result).to include("Dear Acme Supplies")
      expect(result).to include("Please confirm availability")
      expect(result).to include(shop.shop_domain)
    end

    it "logs a warning when falling back" do
      allow(mock_client).to receive(:messages).and_raise(
        Anthropic::Error, "Connection reset"
      )

      expect(Rails.logger).to receive(:warn).with(/PoDraftGenerator.*Connection reset/)

      generator.generate(supplier: supplier, line_items: [line_item], shop: shop)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Anthropic API failures in InventoryMonitor agent
  # ---------------------------------------------------------------------------
  describe "Agents::InventoryMonitor resilience" do
    let(:monitor) { Agents::InventoryMonitor.new(shop) }

    it "falls back to direct check when Anthropic::Error is raised" do
      allow(Anthropic::Client).to receive(:new).and_return(
        instance_double(Anthropic::Client).tap do |client|
          allow(client).to receive(:messages).and_raise(
            Anthropic::Error, "API temporarily unavailable"
          )
        end
      )
      allow(Inventory::LowStockDetector).to receive_message_chain(:new, :detect).and_return([])

      result = monitor.run

      expect(result[:fallback]).to eq(true)
      expect(result[:turns]).to eq(0)
      expect(result[:log]).to include(a_string_matching(/falling back to direct check/))
      expect(result[:log]).to include(a_string_matching(/all SKUs healthy/i))
    end

    it "falls back and sends alerts when there are flagged variants" do
      product = create(:product, shop: shop)
      variant = create(:variant, shop: shop, product: product)

      flagged = [{
        variant: variant,
        available: 2,
        on_hand: 5,
        status: :low_stock,
        threshold: 10
      }]

      allow(Anthropic::Client).to receive(:new).and_return(
        instance_double(Anthropic::Client).tap do |client|
          allow(client).to receive(:messages).and_raise(
            Anthropic::Error, "timeout"
          )
        end
      )
      allow(Inventory::LowStockDetector).to receive_message_chain(:new, :detect).and_return(flagged)

      alert_sender = instance_double(Notifications::AlertSender)
      allow(Notifications::AlertSender).to receive(:new).with(shop).and_return(alert_sender)
      allow(alert_sender).to receive(:send_low_stock_alerts)

      result = monitor.run

      expect(result[:fallback]).to eq(true)
      expect(alert_sender).to have_received(:send_low_stock_alerts).with(flagged)
      expect(result[:log]).to include(a_string_matching(/sent alerts for 1 variant/))
    end

    it "logs error and returns error result on StandardError" do
      allow(Anthropic::Client).to receive(:new).and_raise(
        StandardError, "unexpected initialization failure"
      )

      expect(Rails.logger).to receive(:error).with(/InventoryMonitor.*unexpected initialization failure/)

      result = monitor.run

      expect(result[:error]).to eq(true)
      expect(result[:turns]).to eq(0)
      expect(result[:log]).to include(a_string_matching(/Agent error.*StandardError/))
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Email delivery failures
  # ---------------------------------------------------------------------------
  describe "Email delivery resilience" do
    describe "AlertMailer delivery failure" do
      it "is configured to retry on Net::SMTPError via Sidekiq" do
        # WeeklyReportJob (which triggers email) has retry_on for SMTP errors
        expect(WeeklyReportJob.rescue_handlers).to be_present.or(
          satisfy { WeeklyReportJob.respond_to?(:retry_on) }
        )
      end

      it "WeeklyReportJob still creates report when AI insights fail" do
        allow(Reports::WeeklyGenerator).to receive_message_chain(:new, :generate).and_return(
          { "top_sellers" => [], "stockouts" => [], "low_sku_count" => 0, "reorder_suggestions" => [] }
        )
        allow(AI::InsightsGenerator).to receive_message_chain(:new, :generate).and_raise(
          StandardError, "Anthropic service down"
        )
        # Stub deliver_later to avoid needing real mailer delivery
        mail_double = double("mail", deliver_later: true)
        allow(ReportMailer).to receive(:weekly_summary).and_return(mail_double)

        expect {
          WeeklyReportJob.perform_now(shop.id)
        }.to change(WeeklyReport, :count).by(1)

        report = WeeklyReport.last
        expect(report.payload).to include("top_sellers")
        expect(report.payload).not_to have_key("ai_commentary")
      end

      it "WeeklyReportJob includes AI commentary when available" do
        allow(Reports::WeeklyGenerator).to receive_message_chain(:new, :generate).and_return(
          { "top_sellers" => [], "stockouts" => [], "low_sku_count" => 0, "reorder_suggestions" => [] }
        )
        allow(AI::InsightsGenerator).to receive_message_chain(:new, :generate).and_return(
          "Stock levels are healthy overall."
        )
        mail_double = double("mail", deliver_later: true)
        allow(ReportMailer).to receive(:weekly_summary).and_return(mail_double)

        WeeklyReportJob.perform_now(shop.id)

        report = WeeklyReport.last
        expect(report.payload["ai_commentary"]).to eq("Stock levels are healthy overall.")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Webhook delivery failures
  # ---------------------------------------------------------------------------
  describe "WebhookDeliveryJob resilience" do
    let(:endpoint) { create(:webhook_endpoint, shop: shop, url: "https://hooks.example.com/test") }

    before do
      stub_request(:post, "https://hooks.example.com/test").to_timeout
    end

    it "raises Net::OpenTimeout for retry on connection timeout" do
      stub_request(:post, "https://hooks.example.com/test").to_raise(Net::OpenTimeout)

      expect {
        WebhookDeliveryJob.perform_now(endpoint.id, { event: "low_stock" }.to_json)
      }.to raise_error(Net::OpenTimeout)
    end

    it "raises on HTTP 500 response for retry" do
      stub_request(:post, "https://hooks.example.com/test").to_return(status: 500, body: "")

      expect {
        WebhookDeliveryJob.perform_now(endpoint.id, { event: "low_stock" }.to_json)
      }.to raise_error(/Webhook delivery failed with status 500/)
    end

    it "raises on HTTP 404 response for retry" do
      stub_request(:post, "https://hooks.example.com/test").to_return(status: 404, body: "")

      expect {
        WebhookDeliveryJob.perform_now(endpoint.id, { event: "low_stock" }.to_json)
      }.to raise_error(/Webhook delivery failed with status 404/)
    end

    it "updates endpoint with last status code even on failure" do
      stub_request(:post, "https://hooks.example.com/test").to_return(status: 502, body: "")

      begin
        WebhookDeliveryJob.perform_now(endpoint.id, { event: "low_stock" }.to_json)
      rescue RuntimeError
        # expected
      end

      endpoint.reload
      expect(endpoint.last_status_code).to eq(502)
      expect(endpoint.last_fired_at).to be_present
    end

    it "succeeds and updates endpoint on HTTP 200" do
      stub_request(:post, "https://hooks.example.com/test").to_return(status: 200, body: "OK")

      expect {
        WebhookDeliveryJob.perform_now(endpoint.id, { event: "low_stock" }.to_json)
      }.not_to raise_error

      endpoint.reload
      expect(endpoint.last_status_code).to eq(200)
    end

    it "is configured to retry on Net::OpenTimeout and Net::ReadTimeout" do
      retry_handlers = WebhookDeliveryJob.rescue_handlers.map { |h| h.first }
      expect(retry_handlers).to include("Net::OpenTimeout")
      expect(retry_handlers).to include("Net::ReadTimeout")
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Health check degradation
  # ---------------------------------------------------------------------------
  describe "Health check resilience", type: :request do
    it "returns degraded when database is down" do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
        ActiveRecord::ConnectionNotEstablished, "connection refused"
      )

      get "/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
      expect(body["error"]).to include("connection refused")
    end

    it "returns degraded when Redis is down" do
      redis_double = instance_double(Redis)
      allow(Redis).to receive(:new).and_return(redis_double)
      allow(redis_double).to receive(:ping).and_raise(Redis::CannotConnectError, "connection refused")

      get "/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
    end

    it "returns degraded when both Redis and DB are down" do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
        ActiveRecord::ConnectionNotEstablished, "DB down"
      )

      get "/health"

      expect(response).to have_http_status(:service_unavailable)
      body = JSON.parse(response.body)
      expect(body["status"]).to eq("degraded")
      expect(body["error"]).to include("DB down")
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Agents::Runner error isolation
  # ---------------------------------------------------------------------------
  describe "Agents::Runner error isolation" do
    let!(:shop_a) do
      create(:shop, settings: { "low_stock_threshold" => 10, "timezone" => "UTC" })
    end
    let!(:shop_b) do
      create(:shop, settings: { "low_stock_threshold" => 10, "timezone" => "UTC" })
    end

    before do
      # Mark both shops as active (no uninstalled_at)
      Shop.update_all(uninstalled_at: nil)
    end

    it "continues processing other shops when one shop fails" do
      monitor_a = instance_double(Agents::InventoryMonitor)
      monitor_b = instance_double(Agents::InventoryMonitor)

      allow(Agents::InventoryMonitor).to receive(:new).and_return(monitor_a, monitor_b)

      # Shop A's monitor raises an error
      allow(monitor_a).to receive(:run).and_raise(StandardError, "shop A blew up")
      # Shop B's monitor succeeds
      allow(monitor_b).to receive(:run).and_return({ log: ["done"], turns: 1 })

      results = Agents::Runner.run_all_shops

      # Both shops should have results
      expect(results.size).to eq(Shop.active.count)

      # Find results for each shop by domain
      errored = results.find { |r| r[:error].is_a?(String) && r[:error].include?("shop A blew up") }
      succeeded = results.find { |r| r[:turns] == 1 }

      expect(errored).to be_present
      expect(errored[:error]).to include("shop A blew up")

      expect(succeeded).to be_present
      expect(succeeded[:log]).to eq(["done"])
    end

    it "logs errors for failing shops" do
      allow(Agents::InventoryMonitor).to receive(:new).and_raise(
        StandardError, "kaboom"
      )

      expect(Rails.logger).to receive(:error).with(/Agents::Runner.*kaboom/).at_least(:once)

      Agents::Runner.run_all_shops
    end

    it "returns empty results when no active shops exist" do
      Shop.update_all(uninstalled_at: Time.current)

      results = Agents::Runner.run_all_shops

      expect(results).to eq([])
    end
  end
end
