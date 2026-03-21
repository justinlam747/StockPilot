# frozen_string_literal: true

module LLM
  # Factory for creating LLM provider instances.
  # Detects provider from model name or explicit provider param.
  #
  # Usage:
  #   LLM::Factory.build(model: 'claude-sonnet-4-20250514')
  #   LLM::Factory.build(provider: 'openai', model: 'gpt-4o')
  #   LLM::Factory.build(provider: 'google', model: 'gemini-2.0-flash')
  #   LLM::Factory.from_env  # uses LLM_PROVIDER + LLM_MODEL env vars
  class Factory
    PROVIDER_MAP = {
      'anthropic' => AnthropicProvider,
      'claude' => AnthropicProvider,
      'openai' => OpenAIProvider,
      'gpt' => OpenAIProvider,
      'google' => GoogleProvider,
      'gemini' => GoogleProvider
    }.freeze

    API_KEY_MAP = {
      'anthropic' => 'ANTHROPIC_API_KEY',
      'openai' => 'OPENAI_API_KEY',
      'google' => 'GOOGLE_API_KEY'
    }.freeze

    DEFAULT_MODELS = {
      'anthropic' => 'claude-sonnet-4-20250514',
      'openai' => 'gpt-4o',
      'google' => 'gemini-2.0-flash'
    }.freeze

    class << self
      def build(provider: nil, model: nil, api_key: nil)
        provider_name = resolve_provider(provider, model)
        model ||= DEFAULT_MODELS[provider_name]
        api_key ||= resolve_api_key(provider_name)
        klass = PROVIDER_MAP[provider_name]
        raise ArgumentError, "Unknown LLM provider: #{provider_name}" unless klass

        klass.new(model: model, api_key: api_key)
      end

      def from_env
        build(
          provider: ENV.fetch('LLM_PROVIDER', 'anthropic'),
          model: ENV.fetch('LLM_MODEL', nil),
          api_key: nil
        )
      end

      def available_providers
        API_KEY_MAP.select { |_, env_var| ENV[env_var].present? }.keys
      end

      private

      def resolve_provider(provider, model)
        return normalize_provider(provider) if provider.present?
        return detect_from_model(model) if model.present?

        'anthropic'
      end

      def normalize_provider(name)
        key = name.to_s.downcase
        return 'anthropic' if key.start_with?('claude', 'anthropic')
        return 'openai' if key.start_with?('gpt', 'openai', 'o1', 'o3')
        return 'google' if key.start_with?('gemini', 'google')

        key
      end

      def detect_from_model(model)
        m = model.to_s.downcase
        return 'anthropic' if m.include?('claude')
        return 'openai' if m.match?(/gpt|o1|o3|davinci|chatgpt/)
        return 'google' if m.include?('gemini')

        'anthropic'
      end

      def resolve_api_key(provider_name)
        env_var = API_KEY_MAP[provider_name]
        raise ArgumentError, "No API key env var for provider: #{provider_name}" unless env_var

        ENV.fetch(env_var) do
          raise ArgumentError, "#{env_var} not set. Add it to .env to use #{provider_name}."
        end
      end
    end
  end
end
