# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Landing page', type: :request do
  describe 'GET /' do
    it 'returns success' do
      get '/'
      expect(response).to have_http_status(:ok)
    end

    it 'does not require authentication' do
      get '/'
      expect(response).not_to redirect_to(root_path)
    end
  end
end
