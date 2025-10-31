# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to URL triggers
RSpec.shared_examples "rack url trigger" do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }

  def make_call(account, referer, url: nil)
    raise NotImplementedError, "You must implement 'make_call' to use 'rack url trigger'"
  end

  def it_should_return_survey(referer, url: nil)
    json_response = make_call(account, referer, url: url)

    expect(json_response.dig("survey", "id").to_i).not_to eq(0)
  end

  def it_should_not_return_survey(referer, url: nil)
    expect(make_call(account, referer, url: url)).to eq({})
  end

  describe "triggers" do
    it "returns the survey if there are no triggers defined, no matter the referer" do
      expect(survey.triggers.count).to eq(0)
      expect(survey.suppressers.count).to eq(0)

      ["http://localhost:3000", "http://localhost:3000/bla/bla/bla"].each do |referer|
        it_should_return_survey(referer)
      end
    end

    it "respects trigger rules if no triggers defined,and there are suppressers defined but not applicable to the URL" do
      create(:regexp_trigger, regexp: "^localhost:3000/$", survey: survey, excluded: true)

      expect(survey.reload.triggers.count).to eq(0)
      expect(survey.reload.suppressers.count).to eq(1)

      it_should_return_survey("http://localhost:3000/test")

      it_should_not_return_survey("http://localhost:3000/")
    end

    it "takes url param if any, or referer instead" do
      create(:url_trigger, url: "/abc", survey: survey)

      expect(survey.reload.triggers.count).to eq(1)

      it_should_return_survey("http://localhost:3000/abc")
      it_should_return_survey("http://localhost:3000", url: "http://localhost:3000/abc")
    end

    it "respects trigger rules if there is one url trigger" do
      create(:url_trigger, url: "/abc", survey: survey)

      expect(survey.reload.triggers.count).to eq(1)

      ["http://localhost:3000/abc", "http://localhost:3000/abcdef", "http://localhost:3000/123/abc"].each do |trigger_url|
        it_should_return_survey(trigger_url)
      end

      ["http://localhost:3000/", "http://localhost:3000/bla"].each do |suppressed_url|
        it_should_not_return_survey(suppressed_url)
      end
    end

    it "respects trigger rules if there is one url_matches trigger" do
      create(:url_matches_trigger, url_matches: "localhost:3000", survey: survey)
      create(:url_matches_trigger, url_matches: "www.nytimes.com/section/opinion/", survey: survey)

      expect(survey.reload.triggers.count).to eq(2)

      ["http://localhost:3000/",
       "http://localhost:3000/?query_string=blah",
       "http://www.nytimes.com/section/opinion",
       "http://www.nytimes.com/section/opinion/"].each do |trigger_url|
        it_should_return_survey(trigger_url)
      end

      ["http://localhost:3000/subpage",
       "http://localhost:3000/abcdef/?query_string",
       "http://localhost:3000/123/abc"].each do |suppressed_url|
        it_should_not_return_survey(suppressed_url)
      end
    end

    it "respects trigger rules if there is one regexp trigger" do
      create(:regexp_trigger, regexp: "/abc[0-9]/", survey: survey)

      expect(survey.reload.triggers.count).to eq(1)

      it_should_return_survey("http://localhost:3000/abc3/")

      ["http://localhost:3000",
       "http://localhost:3000/abc00/"].each do |suppressed_url|
        it_should_not_return_survey(suppressed_url)
      end
    end

    it "respects trigger rules if there is more than one regexp trigger" do
      create(:regexp_trigger, regexp: "^domain.com/thank_you/users/[0-9]*$", survey: survey)
      create(:regexp_trigger, regexp: "/payments/[0-9]*/done$", survey: survey)

      expect(survey.reload.triggers.count).to eq(2)

      ["http://domain.com/thank_you/users/123",
       "http://domain.com/payments/123/done"].each do |trigger_url|
        it_should_return_survey(trigger_url)
      end

      ["http://domain.com",
       "http://domain.com/thank_you/users/123/should-not-be-here",
       "http://domain.com/should-not-be-here/thank_you/users/123",
       "http://domain.com/payments/should-not-work/done"].each do |suppressed_url|
        it_should_not_return_survey(suppressed_url)
      end
    end

    it "respects suppressers" do
      create(:regexp_trigger, regexp: "^domain.(org|net|com)", survey: survey)
      create(:regexp_trigger, regexp: "checkout/[0-9]*", survey: survey, excluded: true)
      create(:url_trigger, url: "/contact", survey: survey, excluded: true)

      expect(survey.reload.suppressers.count).to eq(2)

      ["http://domain.com",
       "http://domain.com/anything-else"].each do |trigger_url|
        it_should_return_survey(trigger_url)
      end

      ["http://domain.com/checkout/123",
       "http://domain.com/contact"].each do |suppressed_url|
        it_should_not_return_survey(suppressed_url)
      end
    end
  end
end
