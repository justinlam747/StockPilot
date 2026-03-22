# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Demo::DataCatalog do
  describe '.products' do
    it 'returns an array of product hashes' do
      products = described_class.products
      expect(products).to be_an(Array)
      expect(products.size).to be >= 40
    end

    it 'each product has required keys' do
      described_class.products.each do |p|
        expect(p).to include(:title, :type, :vendor, :price_range, :variants)
        expect(p[:title]).to be_a(String)
        expect(p[:variants]).to be_an(Array)
        expect(p[:variants]).not_to be_empty
        expect(p[:price_range]).to be_a(Range)
      end
    end

    it 'has no duplicate product titles' do
      titles = described_class.products.map { |p| p[:title] }
      expect(titles).to eq(titles.uniq)
    end
  end

  describe '.suppliers' do
    it 'returns an array of supplier hashes' do
      suppliers = described_class.suppliers
      expect(suppliers).to be_an(Array)
      expect(suppliers.size).to be >= 6
    end

    it 'each supplier has required keys' do
      described_class.suppliers.each do |s|
        expect(s).to include(:name, :email, :contact_name, :lead_time_days)
        expect(s[:email]).to match(/@/)
        expect(s[:lead_time_days]).to be_a(Integer)
      end
    end
  end

  describe '.stock_profiles' do
    it 'returns profile distribution summing to ~1.0' do
      profiles = described_class.stock_profiles
      total = profiles.values.sum { |v| v[:pct] }
      expect(total).to be_within(0.01).of(1.0)
    end
  end
end
