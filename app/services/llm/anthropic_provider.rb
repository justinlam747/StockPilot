# frozen_string_literal: true

module LLM
  # Anthropic Claude provider — native tool use support.
  class AnthropicProvider < Base
    def chat(messages:, tools: [], system: nil, max_tokens: 1024)
      client = Anthropic::Client.new(api_key: @api_key)
      params = {
        model: @model,
        max_tokens: max_tokens,
        messages: messages
      }
      params[:system] = system if system
      params[:tools] = tools if tools.any?

      response = client.messages(**params)
      normalize(response)
    rescue Anthropic::Error => e
      raise ProviderError, "Anthropic: #{e.message}"
    end

    private

    def normalize(response)
      {
        'stop_reason' => response['stop_reason'],
        'content' => response['content']
      }
    end
  end
end
