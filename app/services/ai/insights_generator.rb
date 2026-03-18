# frozen_string_literal: true

module AI
  # Generates actionable inventory insights via Claude API.
  class InsightsGenerator
    MODEL = 'claude-sonnet-4-20250514'
    SYSTEM_PROMPT = 'You are an inventory intelligence assistant. ' \
                    'Provide 3-5 concise bullet points with actionable insights ' \
                    "based on the merchant's inventory metrics. " \
                    'Be specific and data-driven.'

    def initialize(shop)
      @shop = shop
    end

    def generate
      metrics = build_metrics
      response = call_api(metrics)
      response.dig('content', 0, 'text')
    rescue Anthropic::Error => e
      Rails.logger.warn("[AI::InsightsGenerator] Anthropic API error: #{e.message}")
      'AI insights temporarily unavailable.'
    end

    private

    def build_metrics
      flagged = Inventory::LowStockDetector.new(@shop).detect
      {
        total_skus: active_variant_count,
        low_stock_count: flagged.count { |fv| fv[:status] == :low_stock },
        out_of_stock_count: flagged.count { |fv| fv[:status] == :out_of_stock },
        top_low_stock: flagged.first(5).map do |fv|
          { sku: fv[:variant].sku, available: fv[:available], threshold: fv[:threshold] }
        end
      }
    end

    def active_variant_count
      Variant.joins(:product)
             .where(products: { deleted_at: nil, shop_id: @shop.id }).count
    end

    def call_api(metrics)
      client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))
      client.messages(
        model: MODEL,
        max_tokens: 512,
        system: SYSTEM_PROMPT,
        messages: [
          { role: 'user', content: "Here are my current inventory metrics:\n#{metrics.to_json}" }
        ]
      )
    end
  end
end
