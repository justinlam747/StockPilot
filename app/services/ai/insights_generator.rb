# frozen_string_literal: true

module AI
  class InsightsGenerator
    MODEL = 'claude-sonnet-4-20250514'

    def initialize(shop)
      @shop = shop
    end

    def generate
      flagged = Inventory::LowStockDetector.new(@shop).detect

      metrics = {
        total_skus: Variant.joins(:product).where(products: { deleted_at: nil, shop_id: @shop.id }).count,
        low_stock_count: flagged.count { |fv| fv[:status] == :low_stock },
        out_of_stock_count: flagged.count { |fv| fv[:status] == :out_of_stock },
        top_low_stock: flagged.first(5).map do |fv|
          { sku: fv[:variant].sku, available: fv[:available], threshold: fv[:threshold] }
        end
      }

      client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))
      response = client.messages(
        model: MODEL,
        max_tokens: 512,
        system: "You are an inventory intelligence assistant. Provide 3-5 concise bullet points with actionable insights based on the merchant's inventory metrics. Be specific and data-driven.",
        messages: [
          { role: 'user', content: "Here are my current inventory metrics:\n#{metrics.to_json}" }
        ]
      )

      response.dig('content', 0, 'text')
    rescue Anthropic::Error => e
      Rails.logger.warn("[AI::InsightsGenerator] Anthropic API error: #{e.message}")
      'AI insights temporarily unavailable.'
    end
  end
end
