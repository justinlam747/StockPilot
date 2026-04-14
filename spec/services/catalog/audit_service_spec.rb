# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::AuditService do
  describe '#summary' do
    it 'counts affected products separately from total issues' do
      shop = create(:shop)
      create(:product, shop: shop, title: 'Clean Product', vendor: 'Vendor', product_type: 'Type', image_url: 'https://img.test/1.png')

      flagged_product = create(:product, shop: shop, title: 'Bad', vendor: nil, product_type: nil, image_url: nil)
      create(:variant, shop: shop, product: flagged_product, sku: nil, price: 0)

      summary = described_class.new(shop).summary

      expect(summary[:total_products]).to eq(2)
      expect(summary[:issue_count]).to be > 1
      expect(summary[:affected_product_count]).to eq(1)
    end
  end
end
