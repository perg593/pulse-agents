# frozen_string_literal: true

require_relative "../../lib/ai_summarization"

describe AISummarization do
  let(:answer_scope) { Answer.all }
  let(:url) { "https://api.openai.com/v1/chat/completions" }

  describe "#summarize" do
    let(:stubbed_summary) { "placeholder_summary" }
    let(:response_body) { "{\"choices\":[{\"message\":{\"content\":\"#{stubbed_summary}\"}}]}" }
    let(:request_body) { "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"Provide a brief overview of the following customer feedback. The overview should be limited to 2 paragraphs focusing on the general sentiment of the customer voice as well as highlighting interesting comments. You may also suggest next steps for the business to act on based on the customer feedbacks but this is not always required.\\n\\nThe customer feedbacks: \\n\\nThe overview:\"}],\"max_tokens\":300}" }

    before do
      @stubbed_request = stub_request(:post, url).
                         with(body: request_body).
                         to_return_json(status: 200, body: response_body, headers: {})
    end

    it "calls Open AI's API" do
      described_class.summarize(answer_scope)

      expect(@stubbed_request).to have_been_requested
    end

    it "returns the API's summary" do
      summary = described_class.summarize(answer_scope)

      expect(summary).to eq stubbed_summary
    end

    context "when the API returns multiple summaries" do
      let(:first_choice) { "{\"message\":{\"content\":\"#{stubbed_summary}\"}}" }
      let(:second_choice) { "{\"message\":{\"content\":\"unexpected_summary\"}}" }

      let(:response_body) { "{\"choices\":[#{first_choice}, #{second_choice}]}" }

      it "returns the first summary in the API response" do
        summary = described_class.summarize(answer_scope)

        expect(summary).to eq stubbed_summary
      end
    end

    describe "retries" do
      # i.e. when we've underestimated the number of tokens in our request
      context "when a context_length_exceeded error is returned" do
        let(:response_body) { JSON.dump({error: {code: "context_length_exceeded"}}) }

        before do
          @stubbed_request = stub_request(:post, url).
                             with(body: request_body).
                             to_return(status: 200, body: response_body, headers: {})

          described_class.summarize(answer_scope)
        rescue StandardError
          # we're expecting this
        end

        it "retries" do
          expect(WebMock).to have_requested(:post, url).times(3)
        end
      end
    end

    describe "max_response_tokens" do
      before do
        stub_request(:post, url).
          to_return_json(status: 200, body: response_body, headers: {})
      end

      context "when not specified" do
        before do
          described_class.summarize(answer_scope)
        end

        it "the default value shows up in the request" do
          expect(WebMock).to have_requested(:post, url).with { |req| req.body =~ /max_tokens":300/ }
        end
      end

      context "when specified" do
        before do
          described_class.summarize(answer_scope, max_response_tokens: 42)
        end

        it "the specified value shows up in the request" do
          expect(WebMock).to have_requested(:post, url).with { |req| req.body =~ /max_tokens":42/ }
        end
      end
    end

    describe "strategies" do
      # Extracted from un-mocked request
      let(:survey_responses) { /The customer feedbacks: text_answer_0.*\\n.*text_answer_1.*\\n.*text_answer_2.*\\n.*text_answer_3.*\\n.*text_answer_4.*\\n.*text_answer_5.*\\n.*text_answer_6.*\\n.*text_answer_7.*\\n.*text_answer_8\\n\\nThe overview:/ }

      before do
        10.times do |i|
          create(:answer, text_answer: "text_answer_#{i}", created_at: i.days.ago)
        end

        stub_request(:post, url).
          to_return_json(status: 200, body: response_body, headers: {})
      end

      context "when none specified" do
        before do
          described_class.summarize(answer_scope)
        end

        it "uses the last x responses" do
          expect(WebMock).to have_requested(:post, url).with { |req| req.body =~ survey_responses }
        end
      end

      context "when 'last responses'" do
        let(:strategy) { AISummarization::STRATEGY_LAST_RESPONSES }

        before do
          described_class.summarize(answer_scope, strategy: strategy)
        end

        it "uses the last x responses" do
          expect(WebMock).to have_requested(:post, url).with { |req| req.body =~ survey_responses }
        end
      end

      context "when 'random'" do
        let(:strategy) { AISummarization::STRATEGY_RANDOM_SAMPLING }

        before do
          described_class.summarize(answer_scope, strategy: strategy)
        end

        it "(probably) does not use the last x responses" do
          expect(WebMock).to have_requested(:post, url)
          expect(WebMock).not_to have_requested(:post, url).with { |req| req.body =~ survey_responses }
        end
      end
    end
  end
end
