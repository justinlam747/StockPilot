require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  let(:shop) { create(:shop) }
  let(:endpoint) { create(:webhook_endpoint, shop: shop, url: "https://example.com/hook") }

  it "records status code on successful delivery" do
    stub_request(:post, "https://example.com/hook")
      .to_return(status: 200, body: "OK")

    described_class.perform_now(endpoint.id, '{"event":"low_stock"}')

    endpoint.reload
    expect(endpoint.last_status_code).to eq(200)
    expect(endpoint.last_fired_at).to be_present
  end

  it "raises on non-success response to trigger retry" do
    stub_request(:post, "https://example.com/hook")
      .to_return(status: 500, body: "Internal Server Error")

    expect {
      described_class.perform_now(endpoint.id, '{"event":"low_stock"}')
    }.to raise_error(RuntimeError, /failed with status 500/)
  end
end
