# frozen_string_literal: true
require 'spec_helper'
include Control::FiltersHelper

describe ReportJob do
  before do
    described_class.delete_all
  end

  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }
  let(:survey_locale_group) { nil }
  let(:user) { create(:user, account: account) }
  let(:current_user_email) { FFaker::Internet.email }

  let(:valid_params) do
    {
      user: user,
      survey: survey,
      survey_locale_group: survey_locale_group,
      current_user_email: current_user_email
    }
  end

  describe "self.already_queued?" do
    let(:admin) { create(:admin) }
    let(:comparison_args) do
      {
        current_user_email: user.email,
        survey_id: survey.id,
        user_id: user.id,
        sudo_from_id: admin.id,
        filters: {},
        survey_locale_group_id: nil,
        status: "in_progress"
      }
    end
    let(:report_job) { described_class.new(**comparison_args) }

    context "when there are no records" do
      it "returns false" do
        expect(described_class.already_queued?(report_job)).to be(false)
      end
    end

    context "when there are no matching records" do
      before do
        existing_job = described_class.create(**comparison_args)
      end

      it "returns false if a single required criterion does not match" do
        non_matching_criteria = {
          user_id: create(:user).id,
          survey_id: create(:survey).id,
          current_user_email: FFaker::Internet.email,
          sudo_from_id: create(:user).id,
          filters: { device_types: ["desktop"]},
          survey_locale_group_id: create(:survey_locale_group).id
        }

        non_matching_criteria.each do |key, value|
          new_args = comparison_args.merge(key => value)

          report_job = described_class.new(**new_args)

          expect(described_class.already_queued?(report_job)).to be(false), "oops! #{key} not tested."
        end
      end
    end

    context "when the provided record matches an existing record" do
      let!(:existing_job) { described_class.create(**comparison_args) }

      it "returns true" do
        expect(described_class.already_queued?(report_job)).to be(true)
      end

      context "when the matching records have not finished processing" do
        it "returns true" do
          described_class.statuses.except("done").each_value do |status_value|
            existing_job.update_column(:status, status_value)
            expect(described_class.already_queued?(report_job)).to be(true), "oops! #{status_value} was considered non matching."
          end
        end
      end
    end
  end

  describe "status" do
    # wtf does that communicate? the record exists?
    it "defaults to 'created'" do
      report_job = described_class.new(**valid_params)
      report_job.save
      expect(report_job.created?).to be(true)
    end
  end

  # Use shared examples to confirm validity of a variety of filter input
  # Might be an abuse of the shared example concept
  context "when filters are provided" do
    it_behaves_like "filter sharing" do
      let(:for_endpoint) { true }

      def it_filters(filters)
        report_filter_args = {}

        filters.each do |filter_key, filter_value|
          case filter_key
          when :date_range
            report_filter_args[:date_range] = filter_value
            report_job = described_class.new(**valid_params.merge.merge(filters: report_filter_args))

            expect(report_job.date_range).to eq filter_value
          when :device_types, :market_ids, :pageview_count, :visit_count, :completion_urls
            report_filter_args[filter_key] = filter_value
            report_job = described_class.new(**valid_params.merge.merge(filters: report_filter_args))

            expect(report_job.filters[filter_key.to_s]).to eq filter_value
          when :possible_answer_id
            # noop
            # unsupported
          else
            raise "Unrecognized data type #{filter_key}"
          end
        end
      end

      def make_records(filter_attribute = nil, attribute_value = nil)
        # noop
      end
    end
  end

  describe "validations" do
    describe "valid" do
      it "can be created with a survey" do
        report_job = described_class.new(**valid_params)

        expect(report_job.valid?).to be true
      end

      context "when a survey locale group is supplied instead of a survey" do
        let(:survey) { nil }
        let(:survey_locale_group) { create(:survey_locale_group, account: account) }

        it "can be created" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be true
        end
      end
    end

    describe "invalid" do
      context "when no user is provided" do
        let(:user) { nil }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.details).to eq(user: [{ error: :blank }])
        end
      end

      context "when no e-mail address is provided" do
        let(:current_user_email) { nil }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.details).to eq(current_user_email: [{ error: :blank }])
        end
      end

      context "when neither a survey nor a survey_locale_group is provided" do
        let(:survey) { nil }
        let(:survey_locale_group) { nil }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.messages[:report_job]).to eq(["Must have either a survey or a survey locale group"])
        end
      end

      context "when both a survey and a survey_locale_group are provided" do
        let(:survey_locale_group) { create(:survey_locale_group, account: account) }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.messages[:report_job]).to eq(["Cannot have both a survey and survey locale group"])
        end
      end

      context "when the survey does not belong to the same account as the user" do
        let(:survey) { create(:survey) }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.messages[:report_job]).to eq(["Access to this survey was denied."])
        end
      end

      context "when the survey locale group does not belong to the same account as the user" do
        let(:survey) { nil }
        let(:survey_locale_group) { create(:survey_locale_group) }

        it "is invalid" do
          report_job = described_class.new(**valid_params)

          expect(report_job.valid?).to be false
          expect(report_job.errors.messages[:report_job]).to eq(["Access to this survey was denied."])
        end
      end
    end
  end
end
