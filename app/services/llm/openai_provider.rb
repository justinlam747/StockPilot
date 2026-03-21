# frozen_string_literal: true

module LLM
  # OpenAI provider — supports GPT-4, GPT-4o, o1, o3, etc.
  # Translates Anthropic-style tool schemas to OpenAI function calling format.
  class OpenAIProvider < Base
    def chat(messages:, tools: [], system: nil, max_tokens: 1024)
      client = OpenAI::Client.new(access_token: @api_key)
      oai_messages = build_messages(messages, system)
      params = {
        model: @model,
        messages: oai_messages,
        max_tokens: max_tokens
      }
      params[:tools] = convert_tools(tools) if tools.any?
      params[:tool_choice] = 'auto' if tools.any?

      response = client.chat(parameters: params)
      normalize(response)
    rescue Faraday::Error, OpenAI::Error => e
      raise ProviderError, "OpenAI: #{e.message}"
    end

    private

    def build_messages(messages, system)
      oai = []
      oai << { role: 'system', content: system } if system
      messages.each { |m| oai.concat(convert_message(m)) }
      oai
    end

    def convert_message(msg)
      role = msg[:role] || msg['role']
      content = msg[:content] || msg['content']

      if content.is_a?(Array)
        convert_array_content(role, content)
      else
        [{ role: role, content: content.to_s }]
      end
    end

    def convert_array_content(role, blocks)
      result = []
      tool_calls = []

      blocks.each do |block|
        type = block[:type] || block['type']
        case type
        when 'text'
          result << { role: role, content: block['text'] || block[:text] }
        when 'tool_use'
          tool_calls << build_tool_call(block)
        when 'tool_result'
          result << build_tool_result(block)
        end
      end

      result << { role: 'assistant', tool_calls: tool_calls } if tool_calls.any?
      result
    end

    def build_tool_call(block)
      {
        id: block['id'] || block[:id],
        type: 'function',
        function: {
          name: block['name'] || block[:name],
          arguments: (block['input'] || block[:input] || {}).to_json
        }
      }
    end

    def build_tool_result(block)
      {
        role: 'tool',
        tool_call_id: block['tool_use_id'] || block[:tool_use_id],
        content: (block['content'] || block[:content]).to_s
      }
    end

    def convert_tools(tools)
      tools.map do |tool|
        {
          type: 'function',
          function: {
            name: tool[:name] || tool['name'],
            description: tool[:description] || tool['description'],
            parameters: tool[:input_schema] || tool['input_schema'] || { type: 'object', properties: {} }
          }
        }
      end
    end

    def normalize(response)
      choice = response.dig('choices', 0)
      return { 'stop_reason' => 'end_turn', 'content' => [] } unless choice

      message = choice['message']
      content = []

      content << { 'type' => 'text', 'text' => message['content'] } if message['content'].present?

      if message['tool_calls'].present?
        message['tool_calls'].each do |tc|
          content << {
            'type' => 'tool_use',
            'id' => tc['id'],
            'name' => tc.dig('function', 'name'),
            'input' => parse_json_safe(tc.dig('function', 'arguments'))
          }
        end
      end

      stop_reason = message['tool_calls'].present? ? 'tool_use' : 'end_turn'
      { 'stop_reason' => stop_reason, 'content' => content }
    end

    def parse_json_safe(str)
      JSON.parse(str || '{}')
    rescue JSON::ParserError
      {}
    end
  end
end
