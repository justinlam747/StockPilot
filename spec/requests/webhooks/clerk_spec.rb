# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Clerk' do
  describe 'POST /webhooks/clerk' do
    context 'with invalid signature' do
      it 'returns unauthorized' do
        post '/webhooks/clerk', params: { type: 'user.created', data: {} }.to_json,
                                headers: { 'Content-Type' => 'application/json' }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'user.created event' do
      it 'creates a user record' do
        allow_any_instance_of(Webhooks::ClerkController).to receive(:verify_clerk_webhook)

        post '/webhooks/clerk',
             params: {
               type: 'user.created',
               data: {
                 id: 'clerk_123',
                 first_name: 'Test',
                 last_name: 'User',
                 email_addresses: [{ email_address: 'test@example.com' }]
               }
             }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'svix-id' => 'msg_test',
               'svix-timestamp' => Time.current.to_i.to_s,
               'svix-signature' => 'v1,test'
             }

        expect(response).to have_http_status(:ok)
        expect(User.find_by(clerk_user_id: 'clerk_123')).to be_present
      end
    end

    context 'user.deleted event' do
      it 'soft-deletes the user' do
        user = create(:user, clerk_user_id: 'clerk_456')
        allow_any_instance_of(Webhooks::ClerkController).to receive(:verify_clerk_webhook)

        post '/webhooks/clerk',
             params: { type: 'user.deleted', data: { id: 'clerk_456' } }.to_json,
             headers: {
               'Content-Type' => 'application/json',
               'svix-id' => 'msg_test',
               'svix-timestamp' => Time.current.to_i.to_s,
               'svix-signature' => 'v1,test'
             }

        expect(response).to have_http_status(:ok)
        expect(user.reload.deleted_at).to be_present
      end
    end
  end
end
