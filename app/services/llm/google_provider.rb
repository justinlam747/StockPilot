# frozen_string_literal: true

module LLM
  # Google Gemini provider via REST API.
  # Translates Anthropic-style tool schemas to Gemini function calling format.
  class GoogleProvider < Base
    GEMINI_URL = 'https://generativelanguage.googleapis.com/v1beta'

    def chat(messages:, tools: [], system: nil, max_tokens: 1024)
      body = build_body(messages, tools, system, max_tokens)
      response = post_api(body)
      normalize(response)
    rescue StandardError => e
      raise ProviderError, "Google: #{e.message}"
    end

    private

    def post_api(body)
      url = "#{GEMINI_URL}/models/#{@model}:generateContent?key=#{@api_key}"
      resp = HTTParty.post(url,
                           headers: { 'Content-Type' => 'application/json' },
                           body: body.to_json,
                           timeout: 60)
      raise ProviderError, "Google API #{resp.code}: #{resp.body}" unless resp.success?

      resp.parsed_response
    end

    def build_body(messages, tools, system, max_tokens)
      body = {
        contents: convert_messages(messages),
        generationConfig: { maxOutputTokens: max_tokens }
      }
      body[:systemInstruction] = { parts: [{ text: system }] } if system
      body[:tools] = [{ functionDeclarations: convert_tools(tools) }] if tools.any?
      body
    end

    def convert_messages(messages)
      messages.map do |msg|
        role = (msg[:role] || msg['role']) == 'assistant' ? 'model' : 'user'
        content = msg[:content] || msg['content']
        { role: role, parts: convert_parts(content) }
      end
    end

    def convert_parts(content)
      return [{ text: content.to_s }] unless content.is_a?(Array)

      content.map do |block|
        type = block[:type] || block['type']
        case type
        when 'text'
          { text: block['text'] || block[:text] }
        when 'tool_use'
          { functionCall: { name: block['name'] || block[:name],
                            args: block['input'] || block[:input] || {} } }
        when 'tool_result'
          { functionResponse: { name: block['name'] || block[:name] || 'tool',
                                response: { result: (block['content'] || block[:content]).to_s } } }
        else
          { text: block.to_s }
        end
      end
    end

    def convert_tools(tools)
      tools.map do |tool|
        schema = tool[:input_schema] || tool['input_schema'] || {}
        {
          name: tool[:name] || tool['name'],
          description: tool[:description] || tool['description'],
          parameters: schema.except('required')
        }
      end
    end

    def normalize(response)
      candidate = response.dig('candidates', 0)
      return { 'stop_reason' => 'end_turn', 'content' => [] } unless candidate

      parts = candidate.dig('content', 'parts') || []
      content = []
      has_tool_call = false

      parts.each do |part|
        if part['text']
          content << { 'type' => 'text', 'text' => part['text'] }
        elsif part['functionCall']
          has_tool_call = true
          content << {
            'type' => 'tool_use',
            'id' => SecureRandom.hex(12),
            'name' => part['functionCall']['name'],
            'input' => part['functionCall']['args'] || {}
          }
        end
      end

      stop_reason = has_tool_call ? 'tool_use' : 'end_turn'
      { 'stop_reason' => stop_reason, 'content' => content }
    end
  end
end
