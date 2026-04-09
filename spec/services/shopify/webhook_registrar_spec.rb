# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify::WebhookRegistrar do
  let(:shop) { create(:shop) }
  let(:mock_client) { instance_double(Shopify::GraphqlClient) }

  before do
    allow(Shopify::GraphqlClient).to receive(:new).with(shop).and_return(mock_client)
  end

  describe '.call' do
    it "delegates to a new instance's register_all" do
      response = { 'webhookSubscriptionCreate' => { 'webhookSubscription' => { 'id' => '123' } } }
      allow(mock_client).to receive(:run_query).and_return(response)

      described_class.call(shop)

      expect(mock_client).to have_received(:run_query).exactly(3).times
    end
  end

  describe '#register_all' do
    let(:registrar) { described_class.new(shop) }

    it 'registers all 3 required webhook topics' do
      webhook_response = {
        'webhookSubscriptionCreate' => {
          'webhookSubscription' => { 'id' => 'gid://shopify/WebhookSubscription/1' },
          'userErrors' => []
        }
      }
      allow(mock_client).to receive(:run_query).and_return(webhook_response)

      registrar.register_all

      expect(mock_client).to have_received(:run_query).exactly(3).times
    end

    it 'registers the app/uninstalled topic with correct variables' do
      allow(mock_client).to receive(:run_query).and_return({
                                                         'webhookSubscriptionCreate' => {
                                                           'webhookSubscription' => { 'id' => '1' },
                                                           'userErrors' => []
                                                         }
                                                       })

      registrar.register_all

      expect(mock_client).to have_received(:run_query).with(
        anything,
        variables: hash_including(
          topic: 'APP_UNINSTALLED',
          webhookSubscription: hash_including(format: 'JSON')
        )
      )
    end

    it 'registers the products/update topic with correct variables' do
      allow(mock_client).to receive(:run_query).and_return({
                                                         'webhookSubscriptionCreate' => {
                                                           'webhookSubscription' => { 'id' => '1' },
                                                           'userErrors' => []
                                                         }
                                                       })

      registrar.register_all

      expect(mock_client).to have_received(:run_query).with(
        anything,
        variables: hash_including(topic: 'PRODUCTS_UPDATE')
      )
    end

    it 'registers the products/delete topic with correct variables' do
      allow(mock_client).to receive(:run_query).and_return({
                                                         'webhookSubscriptionCreate' => {
                                                           'webhookSubscription' => { 'id' => '1' },
                                                           'userErrors' => []
                                                         }
                                                       })

      registrar.register_all

      expect(mock_client).to have_received(:run_query).with(
        anything,
        variables: hash_including(topic: 'PRODUCTS_DELETE')
      )
    end

    it 'generates correct callback URLs for each topic' do
      host = 'https://myapp.example.com'
      allow(ENV).to receive(:fetch).with('SHOPIFY_APP_URL', anything).and_return(host)
      allow(mock_client).to receive(:run_query).and_return({
                                                         'webhookSubscriptionCreate' => {
                                                           'webhookSubscription' => { 'id' => '1' },
                                                           'userErrors' => []
                                                         }
                                                       })

      registrar.register_all

      expect(mock_client).to have_received(:run_query).with(
        anything,
        variables: hash_including(
          webhookSubscription: hash_including(
            callbackUrl: "#{host}/webhooks/app_uninstalled"
          )
        )
      )
    end

    context 'when a webhook registration fails with ShopifyApiError' do
      it 'logs a warning and continues registering remaining topics' do
        call_count = 0
        allow(mock_client).to receive(:run_query) do
          call_count += 1
          raise Shopify::GraphqlClient::ShopifyApiError, 'Registration failed' if call_count == 1

          { 'webhookSubscriptionCreate' => { 'webhookSubscription' => { 'id' => '1' }, 'userErrors' => [] } }
        end

        expect(Rails.logger).to receive(:warn).with(/Failed to register.*Registration failed/)

        registrar.register_all

        expect(mock_client).to have_received(:run_query).exactly(3).times
      end

      it 'does not raise the error to the caller' do
        allow(mock_client).to receive(:run_query)
          .and_raise(Shopify::GraphqlClient::ShopifyApiError, 'API down')

        expect(Rails.logger).to receive(:warn).exactly(3).times

        expect { registrar.register_all }.not_to raise_error
      end
    end
  end

  describe 'REQUIRED_TOPICS' do
    it 'includes all 3 required Shopify webhook topics' do
      expect(described_class::REQUIRED_TOPICS).to contain_exactly(
        'app/uninstalled',
        'products/update',
        'products/delete'
      )
    end

    it 'is frozen' do
      expect(described_class::REQUIRED_TOPICS).to be_frozen
    end
  end
end
