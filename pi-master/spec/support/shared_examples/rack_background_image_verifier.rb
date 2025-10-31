# frozen_string_literal: true

RSpec.shared_examples "background image verifier" do
  def make_call
    raise NotImplementedError, "You must implement 'make_call' to use 'background image verifier'"
  end

  describe "background" do
    let(:background) { nil }

    before do
      account = create(:account)
      @survey = create(:survey, account: account, background: background)

      response = make_call(account)
      @background_value = response['survey']['background']
    end

    context "when a survey background image is configured" do
      let(:background) { Rack::Test::UploadedFile.new("#{Rails.root}/spec/file_fixtures/background.jpg", "image/jpeg") }

      it "serves the survey background image if configured" do
        expect(@background_value).to eq "https://cdn.pulseinsights.com/background/survey/#{@survey.id}/background.jpg"
      end

      it "serves the survey background image with https" do
        expect(@background_value).to include("https")
      end
    end

    context "when a survey background image is not configured" do
      let(:background) { nil }

      it "does not serve survey image" do
        expect(@background_value).to be_nil
      end
    end
  end
end
