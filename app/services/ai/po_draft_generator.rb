# frozen_string_literal: true

module AI
  # Drafts purchase order emails via Claude API with a plain-text fallback.
  class PoDraftGenerator
    MODEL = 'claude-sonnet-4-20250514'
    SYSTEM_PROMPT = 'You write professional, concise purchase order emails ' \
                    'for retail businesses. Include all item details in a clear format.'

    def generate(supplier:, line_items:, shop:)
      prompt = build_prompt(supplier, line_items, shop)
      response = call_api(prompt)
      response.dig('content', 0, 'text')
    rescue Anthropic::Error => e
      Rails.logger.warn("[AI::PoDraftGenerator] Anthropic API error: #{e.message}")
      fallback_draft(supplier: supplier, line_items: line_items, shop: shop)
    end

    private

    def build_prompt(supplier, line_items, shop)
      items_text = format_line_items(line_items)
      delivery = target_delivery_date(supplier)

      <<~PROMPT
        Write a professional purchase order email to #{supplier.name} (#{supplier.email}).
        Store: #{shop.shop_domain}
        Target delivery: #{delivery}

        Items to order:
        #{items_text}

        Keep it concise and professional. Include a summary table of items.
      PROMPT
    end

    def format_line_items(line_items)
      line_items.map do |li|
        "- #{li.sku}: #{li.variant.product.title} — " \
          "#{li.variant.title}, Qty: #{li.qty_ordered}, " \
          "Unit Price: $#{li.unit_price}"
      end.join("\n")
    end

    def target_delivery_date(supplier)
      lead_days = supplier.lead_time_days || 14
      (Date.current + lead_days.days).strftime('%B %d, %Y')
    end

    def call_api(prompt)
      client = Anthropic::Client.new(api_key: ENV.fetch('ANTHROPIC_API_KEY'))
      client.messages(
        model: MODEL, max_tokens: 1024, system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: prompt }]
      )
    end

    def fallback_draft(supplier:, line_items:, shop:)
      items = line_items.map do |li|
        "  - #{li.sku}: #{li.variant.title}, Qty: #{li.qty_ordered}"
      end.join("\n")

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
