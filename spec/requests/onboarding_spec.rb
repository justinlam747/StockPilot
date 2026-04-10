# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Onboarding' do
  let(:user) { create(:user, onboarding_step: 1) }

  before { sign_in_as(user) }

  describe 'GET /onboarding' do
    it 'redirects to current step' do
      get '/onboarding'
      expect(response).to redirect_to('/onboarding/step/1')
    end
  end

  describe 'GET /onboarding/step/1' do
    it 'renders step 1' do
      get '/onboarding/step/1'
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /onboarding/step/1' do
    it 'saves store info and advances to step 2' do
      post '/onboarding/step/1', params: { store_name: 'My Store', store_category: 'apparel' }
      expect(user.reload.store_name).to eq('My Store')
      expect(user.onboarding_step).to eq(2)
      expect(response).to redirect_to('/onboarding/step/2')
    end
  end

  describe 'POST /onboarding/step/2 with skip' do
    before { user.update!(onboarding_step: 2) }

    it 'skips to step 3' do
      post '/onboarding/step/2', params: { skip: true }
      expect(user.reload.onboarding_step).to eq(3)
      expect(response).to redirect_to('/onboarding/step/3')
    end
  end

  describe 'POST /onboarding/step/3' do
    before { user.update!(onboarding_step: 3) }

    it 'completes onboarding and redirects to dashboard' do
      post '/onboarding/step/3', params: { threshold: 15, channels: ['in_app'] }
      expect(user.reload.onboarding_completed?).to be true
      expect(response).to redirect_to('/dashboard')
    end
  end

  describe 'completed user' do
    let(:user) { create(:user, :onboarded) }

    it 'redirects to dashboard' do
      get '/onboarding/step/1'
      expect(response).to redirect_to('/dashboard')
    end
  end
end
