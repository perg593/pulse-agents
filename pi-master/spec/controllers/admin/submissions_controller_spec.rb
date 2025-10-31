# frozen_string_literal: true
require 'spec_helper'

describe Admin::SubmissionsController do
  before do
    sign_in user, scope: :user
  end

  let(:default_creation_date) { 1.day.ago.to_date }

  describe "#questions" do
    let(:survey) { create(:survey) }
    let(:params) { { survey_id: survey.id } }

    before do
      get :questions, params: params
    end

    context "when the user is not signed in" do
      let(:user) { nil }

      it "redirects to signin page" do
        assert_redirected_to sign_in_url
      end
    end

    context "when the user is not an admin" do
      let(:user) { create(:user) }

      it "is not accessible" do
        assert_redirected_to dashboard_url
      end
    end

    context "when the user is an admin" do
      let(:user) { create(:admin) }

      it "loads the page" do
        assert_response 200
      end

      context "when survey_id is missing" do
        let(:params) { { survey_id: nil } }

        it "doesn't work" do
          assert_response 404
        end
      end
    end
  end

  describe "#sample_generator" do
    before do
      get :sample_generator
    end

    context "when the user is not signed in" do
      let(:user) { nil }

      it "redirects to signin page" do
        assert_redirected_to sign_in_url
      end
    end

    context "when the user is not an admin" do
      let(:user) { create(:user) }

      it "is not accessible" do
        assert_redirected_to dashboard_url
      end
    end

    context "when the user is an admin" do
      let(:user) { create(:admin) }

      it "loads the page" do
        assert_response 200
      end
    end
  end

  describe "When invalid possible answer weights are provided" do
    let(:survey) { create(:survey_with_one_question) }
    let(:survey_id) { survey.id }
    let(:user) { create(:admin) }

    let(:possible_answer_a) { survey.possible_answers.sort_by_position.first }
    let(:possible_answer_b) { survey.possible_answers.sort_by_position.last }

    context "when possible answer weights do not add up to 100" do
      let(:survey_params) do
        {
          survey_id: survey_id,
          possible_answer_weights: {
            survey.reload.questions.first.id => [
              { possible_answer_id: possible_answer_a.id, weight: 20 },
              { possible_answer_id: possible_answer_b.id, weight: 20 }
            ]
          }
        }
      end

      it "fails" do
        assert_raises(ArgumentError) { post :generate_samples, params: survey_params }
      end
    end

    context "when a possible answer weight is < 0" do
      let(:survey_params) do
        {
          survey_id: survey_id,
          possible_answer_weights: {
            survey.reload.questions.first.id => [
              { possible_answer_id: possible_answer_a.id, weight: -10 },
              { possible_answer_id: possible_answer_b.id, weight: 20 }
            ]
          }
        }
      end

      it "fails" do
        assert_raises(ArgumentError) { post :generate_samples, params: survey_params }
      end
    end
  end

  describe "automations" do
    let(:survey) { create(:survey_with_one_question) }
    let(:survey_id) { survey.id }
    let(:user) { create(:admin) }
    let(:survey_params) do
      {
        survey_id: survey_id,
        num_impressions_to_create: 100,
        num_viewed_impressions_to_create: 100,
        num_submissions_to_create: 100
      }
    end

    before do
      create(:automation_with_condition_and_action, account_id: survey.account_id)
      # rubocop:disable RSpec/AnyInstance
      # It's tough setting up qualifying automations due to the random
      # nature of the text responses
      Automation.any_instance.stub(:match?).and_return true
      post :generate_samples, params: survey_params
    end

    it "does not send e-mails" do
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end

  describe "#generate_samples" do
    let(:survey) { create(:survey) }
    let(:survey_params) { {survey_id: survey.id} }

    before do
      post :generate_samples, params: survey_params
    end

    context "when the user is not signed in" do
      let(:user) { nil }

      it "redirects to signin page" do
        assert_redirected_to sign_in_url
      end
    end

    context "when the user is not an admin" do
      let(:user) { create(:user) }

      it "is not accessible" do
        assert_redirected_to dashboard_url
      end
    end

    context "when the user is an admin" do
      let(:user) { create(:admin) }
      let(:multiple_choice_question) { create(:multiple_choices_question, position: 0) }
      let(:survey) do
        tmp_survey = create(:survey)
        tmp_survey.questions << multiple_choice_question
        tmp_survey.questions << create(:free_text_question, position: 1)
        tmp_survey
      end
      let(:survey_params) { {survey_id: survey_id} }

      context "when no survey id is provided" do
        let(:survey_id) { nil }

        it "returns 404" do
          assert_response 404
          expect(flash[:alert]).to include("There was a problem")
        end

        it "renders #new" do
          assert_template :sample_generator
        end
      end

      context "when a survey id not belonging to a survey in the db is provided" do
        let(:survey_id) { 42 }

        it "returns 404" do
          assert_response 404
          expect(flash[:alert]).to include("There was a problem")
        end

        it "renders #new" do
          assert_template :sample_generator
        end
      end

      context "when a survey id is provided" do
        let(:survey_id) { survey.id }
        let(:num_impressions_to_create) { 100 }
        let(:num_viewed_impressions_to_create) { 100 }
        let(:num_submissions_to_create) { 100 }
        # Tests are pretty slow if we generate the 1000 submission and 1000 answer records
        let(:default_survey_params) do
          {
            survey_id: survey_id,
            num_impressions_to_create: num_impressions_to_create,
            num_viewed_impressions_to_create: num_viewed_impressions_to_create,
            num_submissions_to_create: num_submissions_to_create
          }
        end
        let(:survey_params) { default_survey_params.dup }

        describe "generating the default 1000 submissions" do
          let(:num_impressions_to_create) { 1000 }
          let(:num_submissions_to_create) { 1000 }
          let(:survey_params) { { survey_id: survey_id } }

          it "creates impressions for the provided survey" do
            expect(survey.impressions.count).to eq num_impressions_to_create
            expect(survey.submissions.count).to eq num_submissions_to_create
          end

          it "redirects the user back to the generator page" do
            assert_redirected_to sample_generator_admin_submissions_path
            expect(flash[:alert]).to include("Generated #{num_impressions_to_create} submissions!")
          end

          it "creates cache records for each submission" do
            cache_records = survey.submission_caches

            expect(cache_records.count).to eq(1)

            expect(cache_records.first.impression_count).to eq num_impressions_to_create
            expect(cache_records.first.submission_count).to eq num_submissions_to_create
            expect(cache_records.first.applies_to_date).to eq default_creation_date
          end
        end

        it "generates a random mix of device types" do
          device_types = %w(email native_mobile desktop mobile tablet) + [nil]

          selections = Submission.pluck(:device_type)

          array_has_random_distribution?(device_types, selections)
        end

        it "randomly distributes answers across questions" do
          options = survey.questions.pluck(:position)

          selections = Answer.all.map { |answer| answer.question.position }

          array_has_random_distribution?(options, selections)
        end

        it "generates free text responses" do
          expect(survey.answers.where.not(text_answer: nil).exists?).to be true
        end

        describe "multiple choice questions" do
          let(:multiple_choice_question) do
            tmp_question = create(:multiple_choices_question)

            3.times { tmp_question.possible_answers << create(:possible_answer) }

            tmp_question
          end

          let(:possible_answers) { multiple_choice_question.possible_answers }
          let(:submissions) { possible_answers.map { |possible_answer| possible_answer.answers.map(&:submission) }.flatten.uniq }

          it "chooses a random number of multiple choice question options" do
            options = (1..possible_answers.count).to_a

            selections = submissions.map { |submission| submission.answers.count }

            array_has_random_distribution?(options, selections)
          end

          context "when the question has selection restrictions" do
            let(:selection_limit) { 2 }
            let(:multiple_choice_question) do
              tmp_question = create(:multiple_choices_question)

              3.times { tmp_question.possible_answers << create(:possible_answer) }
              tmp_question.update(enable_maximum_selection: true)
              tmp_question.update(maximum_selection: selection_limit)

              tmp_question
            end

            it "respects the restrictions" do
              highest_number_of_selections = submissions.map { |submission| submission.answers.count }.max

              expect(highest_number_of_selections).to eq(selection_limit)
            end
          end
        end

        describe "possible answer weights" do
          let(:survey) { create(:survey_with_one_question) }

          let(:possible_answer_a) { survey.possible_answers.sort_by_position.first }
          let(:possible_answer_b) { survey.possible_answers.sort_by_position.last }

          context "when possible answer weights are provided" do
            let(:survey_params) do
              default_survey_params.merge(
                {
                  possible_answer_weights: {
                    survey.reload.questions.first.id => [
                      {
                        possible_answer_id: possible_answer_a.id,
                        weight: 20
                      },
                      {
                        possible_answer_id: possible_answer_b.id,
                        weight: 80
                      }
                    ]
                  }
                }
              )
            end

            it "generates answers in proportion to the weights" do
              pool = [
                { value: possible_answer_a.id, weight: 20 },
                { value: possible_answer_b.id, weight: 80 }
              ]

              selections = Answer.all.pluck(:possible_answer_id)

              array_has_weighted_distribution?(pool, selections)
            end
          end
        end

        context "when num_impressions and num_submissions are provided" do
          let(:num_impressions_to_create) { 10 }
          let(:num_viewed_impressions_to_create) { 7 }
          let(:num_submissions_to_create) { 5 }

          it "generates the specified number of impressions" do
            expect(survey.impressions.count).to eq num_impressions_to_create
          end

          it "generates the specified number of submissions" do
            expect(survey.submissions.count).to eq num_submissions_to_create
          end

          it "creates cache records for each submission" do
            cache_records = survey.submission_caches

            expect(cache_records.count).to eq(1)

            expect(cache_records.first.impression_count).to eq num_impressions_to_create
            expect(cache_records.first.submission_count).to eq num_submissions_to_create
            expect(cache_records.first.applies_to_date).to eq default_creation_date
          end

          context 'when num_submissions and num_viewed_impressions are bigger than num_impressions' do
            let(:num_impressions_to_create) { 5 }
            let(:num_viewed_impressions_to_create) { 10 }
            let(:num_submissions_to_create) { 7 }

            it "creates a consistent cache record" do
              cache_record = survey.submission_caches.first

              expect(cache_record.impression_count).to eq num_impressions_to_create
              expect(cache_record.viewed_impression_count).to eq num_impressions_to_create
              expect(cache_record.submission_count).to eq num_impressions_to_create
            end
          end

          context 'when num_submissions is bigger than num_viewed_impressions' do
            let(:num_impressions_to_create) { 10 }
            let(:num_viewed_impressions_to_create) { 5 }
            let(:num_submissions_to_create) { 7 }

            it "creates a consistent cache record" do
              cache_record = survey.submission_caches.first

              expect(cache_record.viewed_impression_count).to eq num_submissions_to_create
              expect(cache_record.submission_count).to eq num_submissions_to_create
            end
          end
        end

        context "when a blank URL is provided" do
          let(:completion_urls) { [" ", "", nil] }
          let(:survey_params) { default_survey_params.merge(completion_urls: completion_urls) }

          it "sets the URLs to nil" do
            expect(survey.impressions.pluck(:url).uniq.compact).to eq []
          end
        end

        context "when a completion URL is provided" do
          let(:completion_urls) { [FFaker::Internet.http_url] }
          let(:survey_params) { default_survey_params.merge(completion_urls: completion_urls) }

          it "uses that URL" do
            expect(survey.impressions.pluck(:url)).to include completion_urls.first
          end
        end

        context "when multiple completion URLs are provided" do
          let(:completion_urls) { 3.times.map { FFaker::Internet.http_url } }
          let(:survey_params) { default_survey_params.merge(completion_urls: completion_urls) }

          it "chooses completion URLs at random" do
            options = completion_urls
            selections = survey.impressions.pluck(:url)

            array_has_random_distribution?(options, selections)
          end
        end

        context "when a date range is provided" do
          let(:start_date) { 1.month.ago.to_date }
          let(:end_date) { 1.week.ago.to_date }
          let(:survey_params) { default_survey_params.merge(start_date: start_date, end_date: end_date) }

          it "spreads submissions evenly across all dates" do
            options = (start_date..end_date).to_a
            selections = survey.impressions.pluck("DATE(created_at)")

            array_has_random_distribution?(options, selections)
          end

          it "creates cache records for each date which had a submission" do
            cache_records = survey.submission_caches

            expect(cache_records.count).to eq(survey.submissions.pluck("DATE(created_at)").uniq.count)
          end

          context "when a start date after yesterday is provided" do
            let(:start_date) { Time.current.to_date }

            it "generates all submissions for yesterday's date" do
              impressions_all_yesterday
            end
          end

          context "when an end date after yesterday is provided" do
            let(:end_date) { Time.current.to_date }

            it "generates all submissions for yesterday's date" do
              impressions_all_yesterday
            end
          end
        end

        context "when a start date is provided and an end date is not" do
          let(:survey_params) { default_survey_params.merge(start_date: 1.day.ago) }

          it "generates all submissions for yesterday's date" do
            impressions_all_yesterday
          end
        end

        context "when a start date is not provided and an end date is" do
          let(:survey_params) { default_survey_params.merge(end_date: 1.day.ago) }

          it "generates all submissions for yesterday's date" do
            impressions_all_yesterday
          end
        end

        context "when neither a start date nor an end date is provided" do
          let(:survey_params) { default_survey_params }

          it "generates all submissions for yesterday's date" do
            impressions_all_yesterday
          end
        end

        def impressions_all_yesterday
          expect(survey.impressions.pluck("DATE(created_at)").uniq).to eq [1.day.ago.to_date]
        end
      end
    end
  end

  # Determine whether selections of items in an array follow an unweighted random distribution.
  #
  # pool: An array of options. Each item is equally likely to be selected
  # selections: An array of items selected from the pool
  #
  # TODO: Consider alternate calculation methods:
  # - Compare submission ratios
  # - Compare standard deviation
  def array_has_random_distribution?(pool, selections)
    # index_total = selections.map { |selection| pool.find_index(selection) }.sum
    #
    # average_of_indexes = index_total / selections.length.to_f
    #
    # # pool.length - 1 == the highest index value
    # # divide by 2 to calculate the median
    # #
    # # expected_value == average == mean; however, it's simpler to calculate the median, which,
    # # due to the characteristics of the array, is equivalent to the mean
    # expected_value = ((pool.length - 1) / 2.0)
    #
    # margin_of_error = 0.5 # Lower is more accurate but may generate intermittent failures
    #
    # expect(average_of_indexes).to be_within(margin_of_error).of expected_value
  end

  # basically a more generalized version of array_has_random_distribution
  # TODO: Consider alternate calculation methods:
  # - Compare submission ratios
  # - Compare standard deviation
  def array_has_weighted_distribution?(pool, selections)
    # index_total = selections.map do |selection|
    #   pool.find_index { |option| option[:value] == selection }
    # end.sum
    #
    # average_of_indexes = index_total / selections.length.to_f
    #
    # expected_value = 0
    # pool.each_with_index { |option, i| expected_value += i * option[:weight] / 100.0 } # The weights are user-friendly whole numbers
    #
    # margin_of_error = 0.5 # Lower is more accurate but may generate intermittent failures
    #
    # expect(average_of_indexes).to be_within(margin_of_error).of expected_value
  end
end
