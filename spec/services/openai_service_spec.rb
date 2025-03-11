require 'rails_helper'

RSpec.describe OpenaiService do
  let(:service) { described_class.new }
  let(:api_key) { 'test_api_key' }
  let(:success_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'This is a test response from OpenAI'
          }
        }
      ]
    }
  end
  let(:error_response) { { 'error' => 'API error' } }

  before do
    # Use a more flexible approach to stub ENV
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('OPENAI_ACCESS_TOKEN').and_return(api_key)
  end

  describe '#initialize' do
    it 'fetches the API key from environment variables' do
      expect(ENV).to receive(:fetch).with('OPENAI_ACCESS_TOKEN')
      described_class.new
    end
  end

  describe '#chat' do
    let(:messages) { [{ role: 'user', content: 'Hello' }] }
    let(:url) { 'https://api.openai.com/v1/chat/completions' }
    let(:headers) do
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }
    end
    let(:payload) do
      {
        model: 'gpt-3.5-turbo',
        messages: messages,
        max_tokens: 500
      }
    end
    let(:mock_response) { instance_double(Faraday::Response) }

    context 'when the API request is successful' do
      before do
        allow(mock_response).to receive(:status).and_return(200)
        allow(mock_response).to receive(:body).and_return(success_response.to_json)
        allow(Faraday).to receive(:post).and_return(mock_response)
        allow(Rails.logger).to receive(:info)
      end

      it 'returns the parsed JSON response' do
        expect(service.chat(messages)).to eq(success_response)
      end

      it 'logs the request and response' do
        expect(Rails.logger).to receive(:info).with(/Requesting OpenAI with:/)
        expect(Rails.logger).to receive(:info).with(/Response status: 200/)
        service.chat(messages)
      end

      it 'respects the custom max_tokens parameter' do
        custom_payload = payload.merge(max_tokens: 1000)
        expect(Faraday).to receive(:post) do |actual_url, actual_payload, actual_headers|
          expect(actual_url).to eq(url)
          expect(JSON.parse(actual_payload)).to include('max_tokens' => 1000)
          expect(actual_headers).to eq(headers)
          mock_response
        end
        service.chat(messages, max_tokens: 1000)
      end
    end

    context 'when the API request fails' do
      before do
        allow(mock_response).to receive(:status).and_return(400)
        allow(mock_response).to receive(:body).and_return('Bad request')
        allow(Faraday).to receive(:post).and_return(mock_response)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      it 'returns an error hash' do
        result = service.chat(messages)
        expect(result).to include('error')
        expect(result['error']).to include('API request failed with status 400')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/OpenAI API error \(400\): Bad request/)
        service.chat(messages)
      end
    end
  end

  describe '#resume_chat' do
    let(:query) { 'Tell me about Maxwell' }
    let(:system_message) { { role: 'system', content: OpenaiService::SYSTEM_PROMPT } }
    let(:expected_messages) { [system_message, { role: 'user', content: query }] }

    context 'when content is present in the response' do
      before do
        allow(service).to receive(:chat).with(expected_messages).and_return(success_response)
      end

      it 'returns the content from the response' do
        expect(service.resume_chat(query)).to eq('This is a test response from OpenAI')
      end
    end

    context 'when the API returns an error' do
      before do
        allow(service).to receive(:chat).with(expected_messages).and_return(error_response)
      end

      it 'returns a formatted error message' do
        expect(service.resume_chat(query)).to eq('Error: API error')
      end
    end

    context 'when there is an unexpected response format' do
      before do
        allow(service).to receive(:chat).with(expected_messages).and_return({})
      end

      it 'returns a generic error message' do
        expect(service.resume_chat(query)).to eq("I'm sorry, I encountered an error processing your request.")
      end
    end
  end

  describe '#system_message' do
    it 'returns a hash with the SYSTEM_PROMPT' do
      expect(service.send(:system_message)).to eq({
        role: 'system',
        content: OpenaiService::SYSTEM_PROMPT
      })
    end
  end
end 