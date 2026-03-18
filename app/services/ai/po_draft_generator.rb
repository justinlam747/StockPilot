# frozen_string_literal: true

module AI
  class PoDraftGenerator
    MODEL = 'claude-sonnet-4-20250514'

    def generate(supplier:, line_items:, shop:)
      items_text = line_items.map do |li|
        "- #{li.sku}: #{li.variant.product.title} — #{li.variant.title}, Qty: #{li.qty_ordered}, Unit Price: $#{li.unit_price}"
      end.join("\n")

      prompt = <<~PROMPT
        Write a professional purchase order email to #{supplier.name} (#{supplier.email}).
        Store: #{shop.shop_domain}
        Target delivery: #{(Date.current + (supplier.lead_time_days || 14).days).strftime('%B %d, %Y')}

        Items to order:
        #{items_text}

        Keep it concise and professional. Include a summary table of items.
      PROMPT

      client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))
      response = client.messages(
        model: MODEL,
        max_tokens: 1024,
        system: 'You write professional, concise purchase order emails for retail businesses. Include all item details in a clear format.',
        messages: [
          { role: 'user', content: prompt }
        ]
      )

      response.dig('content', 0, 'text')
    rescue Anthropic::Error => e
      Rails.logger.warn("[AI::PoDraftGenerator] Anthropic API error: #{e.message}")
      fallback_draft(supplier: supplier, line_items: line_items, shop: shop)
    end

    private

    def fallback_draft(supplier:, line_items:, shop:)
      items = line_items.map { |li| "  - #{li.sku}: #{li.variant.title}, Qty: #{li.qty_ordered}" }.join("\n")

      <<~DRAFT
        Dear #{supplier.name},

        We would like to place the following order:

        #{items}

        Please confirm availability and expected delivery date.

        Thank you,
        #{shop.shop_domain}
      DRAFT
    end
  end
end
