# frozen_string_literal: true

require 'rails_helper'
require 'nokogiri'

RSpec.describe 'Landing page' do
  describe 'GET /' do
    it 'returns success' do
      get '/'
      expect(response).to have_http_status(:ok)
    end

    it 'does not require authentication' do
      get '/'
      expect(response).not_to redirect_to(root_path)
    end

    it 'renders a Shopify connect form that posts the shop domain' do
      get '/'

      document = Nokogiri::HTML(response.body)
      form = document.at_css("form[action='/auth/shopify'][method='post']")

      expect(form).to be_present
      expect(form.at_css("input[name='shop'][required]")).to be_present
      expect(document.at_css("a[href='/auth/shopify']")).to be_nil
      expect(document.at_css("a[href='/dev/login']")).to be_nil
    end
  end
end
