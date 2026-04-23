# frozen_string_literal: true

module Agents
  # Produces an operator-facing run summary, with optional LLM support.
  class SummaryClient
    SYSTEM_PROMPT = <<~PROMPT
      You are an inventory operations agent for a Shopify merchant.
      Summarize the current inventory risk in 3 short sentences.
      Focus on urgency, specific SKUs, and the next actions the merchant should review.
    PROMPT

    def initialize(shop, http_client: HTTParty)
      @shop = shop
      @http_client = http_client
    end

    def provider_name
      provider = ENV.fetch('AI_PROVIDER', 'disabled').to_s.downcase
      return 'openai' if provider == 'openai' && openai_api_key.present?
      return 'anthropic' if provider == 'anthropic' && anthropic_api_key.present?

      'fallback'
    end

    def generate(context)
      case provider_name
      when 'openai' then openai_summary(context) || fallback_summary(context)
      when 'anthropic' then anthropic_summary(context) || fallback_summary(context)
      else fallback_summary(context)
      end
    rescue StandardError => e
      Rails.logger.warn("[Agents::SummaryClient] #{e.class}: #{e.message}")
      fallback_summary(context)
    end

    private

    def openai_summary(context)
      response = @http_client.post(
        "#{openai_base_url}/chat/completions",
        headers: {
          'Authorization' => "Bearer #{openai_api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: openai_model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: context.except('result_payload').to_json }
          ],
          temperature: 0.2
        }.to_json,
        timeout: 8
      )

      text = response.parsed_response.dig('choices', 0, 'message', 'content')
      raise "OpenAI summary failed with #{response.code}" if response.code.to_i >= 400

      text.to_s.strip.presence
    end

    def anthropic_summary(context)
      response = @http_client.post(
        "#{anthropic_base_url}/messages",
        headers: {
          'x-api-key' => anthropic_api_key,
          'anthropic-version' => '2023-06-01',
          'Content-Type' => 'application/json'
        },
        body: {
          model: anthropic_model,
          max_tokens: 250,
          system: SYSTEM_PROMPT,
          messages: [
            { role: 'user', content: context.except('result_payload').to_json }
          ]
        }.to_json,
        timeout: 8
      )

      text = response.parsed_response.dig('content', 0, 'text')
      raise "Anthropic summary failed with #{response.code}" if response.code.to_i >= 400

      text.to_s.strip.presence
    end

    def fallback_summary(context)
      counts = context.fetch('counts', {})
      lines = []
      lines << "#{@shop.shop_domain} has #{context['flagged_count'].to_i} flagged SKU(s): " \
               "#{counts['low_stock'].to_i} low stock and #{counts['out_of_stock'].to_i} out of stock."

      top_items = Array(context['top_items']).first(3)
      if top_items.any?
        labels = top_items.map do |item|
          "#{item['sku'] || 'Unknown SKU'} (#{item['available']} left)"
        end
        lines << "Most urgent items: #{labels.join(', ')}."
      end

      supplier_recommendations = Array(context['supplier_recommendations']).first(2)
      if supplier_recommendations.any?
        supplier_notes = supplier_recommendations.map do |supplier|
          "#{supplier['supplier_name']} (#{supplier['item_count']} SKU#{'s' unless supplier['item_count'] == 1})"
        end
        lines << "Supplier follow-up: #{supplier_notes.join(', ')}."
      end

      supplierless_count = counts['supplierless'].to_i
      if supplierless_count.positive?
        lines << "#{supplierless_count} flagged SKU(s) are still missing a supplier assignment."
      end

      if context['correction'].present?
        lines << "Operator correction applied: #{truncate(context['correction'])}."
      end

      lines.join(' ')
    end

    def truncate(text, max_length = 140)
      return text if text.length <= max_length

      "#{text.first(max_length - 3)}..."
    end

    def openai_api_key
      ENV['OPENAI_API_KEY']
    end

    def anthropic_api_key
      ENV['ANTHROPIC_API_KEY']
    end

    def openai_model
      ENV.fetch('OPENAI_MODEL', 'gpt-4.1-mini')
    end

    def anthropic_model
      ENV.fetch('ANTHROPIC_MODEL', 'claude-3-5-sonnet-latest')
    end

    def openai_base_url
      ENV.fetch('OPENAI_BASE_URL', 'https://api.openai.com/v1')
    end

    def anthropic_base_url
      ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com/v1')
    end
  end
end
