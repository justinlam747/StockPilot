require "rails_helper"

RSpec.describe Shopify::GraphqlClient do
  let(:shop) { create(:shop) }
  let(:client) { described_class.new(shop) }

  before do
    allow(ShopifyAPI::Clients::Graphql::Admin).to receive(:new).and_return(mock_gql_client)
  end

  let(:mock_gql_client) { instance_double(ShopifyAPI::Clients::Graphql::Admin) }

  describe "#query" do
    it "returns data on success" do
      response = double(body: { "data" => { "products" => [] } })
      allow(mock_gql_client).to receive(:query).and_return(response)

      result = client.query("{ products { nodes { id } } }")
      expect(result).to eq({ "products" => [] })
    end

    it "retries on throttle then raises" do
      error_response = double(body: {
        "errors" => [{ "message" => "Throttled", "extensions" => { "code" => "THROTTLED" } }]
      })
      allow(mock_gql_client).to receive(:query).and_return(error_response)
      allow(client).to receive(:sleep)

      expect {
        client.query("{ products { nodes { id } } }")
      }.to raise_error(Shopify::GraphqlClient::ShopifyThrottledError)
    end

    it "raises ShopifyApiError on non-throttle errors" do
      error_response = double(body: {
        "errors" => [{ "message" => "Something broke", "extensions" => { "code" => "INTERNAL_ERROR" } }]
      })
      allow(mock_gql_client).to receive(:query).and_return(error_response)

      expect {
        client.query("{ products { nodes { id } } }")
      }.to raise_error(Shopify::GraphqlClient::ShopifyApiError, "Something broke")
    end
  end
end
