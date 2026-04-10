# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security headers' do
  let(:user) { create(:user, :with_shop) }

  before do
    sign_in_as(user)
    get '/dashboard'
  end

  it 'sets Strict-Transport-Security' do
    expect(response.headers['Strict-Transport-Security']).to include('max-age=31536000')
  end

  it 'sets X-Content-Type-Options' do
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
  end

  it 'sets X-Frame-Options' do
    expect(response.headers['X-Frame-Options']).to be_present
  end

  it 'sets Content-Security-Policy' do
    csp = response.headers['Content-Security-Policy']
    expect(csp).to include("default-src 'self'")
  end

  it 'sets Referrer-Policy' do
    expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
  end

  it 'sets Permissions-Policy' do
    expect(response.headers['Permissions-Policy']).to include('camera=()')
  end
end
