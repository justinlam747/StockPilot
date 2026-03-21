# frozen_string_literal: true

module LLM
  # Abstract base class for LLM providers.
  # All providers must implement #chat(messages:, tools:, system:, max_tokens:)
  # and return a normalized response hash.
  class Base
    class ProviderError < StandardError; end

    def initialize(model:, api_key:)
      @model = model
      @api_key = api_key
    end

    # @return [Hash] { stop_reason: String, content: Array<Hash> }
    #   content blocks: { type: 'text', text: '...' }
    #                   { type: 'tool_use', id: '...', name: '...', input: {} }
    def chat(messages:, tools: [], system: nil, max_tokens: 1024)
      raise NotImplementedError, "#{self.class}#chat must be implemented"
    end

    # Human-readable provider name
    def provider_name
      self.class.name.demodulize.underscore.gsub('_provider', '')
    end

    private

    def normalize_tool_schema(tools)
      tools
    end
  end
end
