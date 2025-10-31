# frozen_string_literal: true
require 'spec_helper'

# Not sure whether this is the best place for this.
AppliedTagBulkActionResponseSchema = Dry::Schema.JSON do
  required(:response).array(:hash) do
    required(:answerId).value(:integer)
    required(:appliedTags).value(Dry.Types::Array.of(FreeTextResponseAppliedTagSchema))
  end
end

describe Control::AppliedTagsController do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:survey) { create(:survey, account: account) }
  let(:question) { create(:question, survey: survey) }

  describe 'PATCH #approve' do
    before do
      sign_in user
    end

    context 'when an applied tag is not found' do
      it 'returns 404' do
        post :approve, params: { id: 999999 }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when an applied tag does not belong to the current account' do
      it 'returns 404' do
        other_question = create(:question)
        tag = create(:tag, question: other_question)
        applied_tag = create(:automatically_applied_tag, tag: tag)

        post :approve, params: { id: applied_tag.id, question_id: question.id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when an applied tag is found' do
      it 'approves the applied tag' do
        tag = create(:tag, question: question)
        applied_tag = create(:automatically_applied_tag, tag: tag)

        expect(applied_tag.reload.is_good_automation).to be false
        post :approve, params: { id: applied_tag.id, question_id: question.id }
        expect(applied_tag.reload.is_good_automation).to be true
      end
    end
  end

  describe 'DELETE #remove' do
    before do
      sign_in user
    end

    context 'when an applied tag is not found' do
      it 'returns 404' do
        delete :remove, params: { id: 999999 }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when an applied tag does not belong to the current account' do
      it 'returns 404' do
        other_question = create(:question)
        tag = create(:tag, question: other_question)
        applied_tag = create(:automatically_applied_tag, tag: tag)

        post :remove, params: { id: applied_tag.id, question_id: question.id }
        expect(response).to have_http_status :not_found
      end
    end

    context 'when an applied tag is found' do
      it 'removes the applied tag' do
        tag = create(:tag, question: question)
        applied_tag = create(:automatically_applied_tag, tag: tag)

        delete :remove, params: { id: applied_tag.id, question_id: question.id }
        expect(AppliedTag.find_by(id: applied_tag.id)).to be_nil
      end
    end
  end

  describe "POST #create_for_answers" do
    let(:question) { create(:free_text_question, survey: survey) }
    let(:tag) { create(:tag, question: question) }

    before do
      @answers_to_tag = []
      3.times { @answers_to_tag << create(:free_text_answer, question: question) }
      3.times { create(:free_text_answer, question: question) }
    end

    it_behaves_like "shared authorization" do
      def make_call
        post :create_for_answers, params: { tag_id: tag.id, answer_ids: @answers_to_tag.pluck(:id) }
      end

      def reporting_only_assertion
        assert_redirected_to dashboard_path
      end
    end

    context "when the answers belong to another account" do
      before do
        sign_in user

        answers_to_tag = 3.times.map { create(:free_text_answer, question: create(:question)) }

        post :create_for_answers, params: { tag_id: tag.id, answer_ids: answers_to_tag.pluck(:id) }
      end

      it "redirects to dashboard" do
        assert_redirected_to dashboard_path
      end
    end

    context "when a full access user for the account is signed in" do
      before do
        sign_in user
        post :create_for_answers, params: { tag_id: tag.id, answer_ids: @answers_to_tag.pluck(:id) }
      end

      it "creates an AppliedTag record for each specified answer" do
        expect(AppliedTag.where(tag_id: tag.id).count).to be @answers_to_tag.count
      end

      it "returns valid response" do
        assert_valid_schema AppliedTagBulkActionResponseSchema, JSON.parse(response.body)
      end

      it "returns expected data" do
        data = JSON.parse(response.body)

        assert_expected_applied_tag_bulk_action_response_schema_data(@answers_to_tag, data["response"])
      end
    end
  end

  describe "DELETE #remove_from_answers" do
    let(:question) { create(:free_text_question, survey: survey) }
    let(:tag_to_remove) { create(:tag, question: question) }

    before do
      @answers_to_detag = []

      3.times do
        answer = create(:free_text_answer, question: question)

        @answers_to_detag << answer
        create(:applied_tag, tag: tag_to_remove, answer: answer)
        create(:applied_tag, tag: create(:tag, question: question), answer: answer)
        create(:applied_tag, tag: create(:tag, question: question), answer: answer)
      end

      3.times do
        answer = create(:free_text_answer, question: question)

        create(:applied_tag, tag: tag_to_remove, answer: answer)
        create(:applied_tag, tag: create(:tag, question: question), answer: answer)
      end
    end

    it_behaves_like "shared authorization" do
      def make_call
        delete :remove_from_answers, params: { tag_id: tag_to_remove.id, answer_ids: @answers_to_detag.pluck(:id) }
      end

      def reporting_only_assertion
        assert_redirected_to dashboard_path
      end
    end

    context "when the answers belong to another account" do
      before do
        sign_in user

        answers_to_detag = 3.times.map { create(:free_text_answer, question: create(:question)) }

        delete :remove_from_answers, params: { tag_id: tag_to_remove.id, answer_ids: answers_to_detag.pluck(:id) }
      end

      it "redirects to dashboard" do
        assert_redirected_to dashboard_path
      end
    end

    context "when a full access user for the account is signed in" do
      before do
        sign_in user
        @num_applied_tags_before_deletion = AppliedTag.count
        delete :remove_from_answers, params: { tag_id: tag_to_remove.id, answer_ids: @answers_to_detag.pluck(:id) }
      end

      it "removes AppliedTag records associated with the provided tag for each specified answer" do
        # records are destroyed
        expect(AppliedTag.where(answer: @answers_to_detag, tag: tag_to_remove).exists?).to be false

        # irrelevant records are preserved
        expect(AppliedTag.count).to eq @num_applied_tags_before_deletion - @answers_to_detag.count
      end

      it "returns valid response" do
        data = JSON.parse(response.body)
        assert_valid_schema AppliedTagBulkActionResponseSchema, data
      end

      it "returns expected data" do
        data = JSON.parse(response.body)

        assert_expected_applied_tag_bulk_action_response_schema_data(@answers_to_detag, data["response"])
      end
    end
  end

  # Where data is AppliedTagBulkActionResponseSchema["response"]
  # TODO: Simplify
  # rubocop:disable Metrics/AbcSize
  def assert_expected_applied_tag_bulk_action_response_schema_data(answers, data)
    expect(answers.count).to eq data.count

    answers.each_with_index do |answer, answer_index|
      answer_data = data[answer_index]

      expect(answer_data["answerId"]).to eq answer.id
      expect(answer_data["appliedTags"].count).to eq answer.applied_tags.count

      # TODO: Consider whether this could be shared with free_text_response_presenter_spec
      answer.applied_tags.joins(:tag).order("tags.name").each_with_index do |applied_tag, applied_tag_index|
        applied_tag_props = answer_data["appliedTags"][applied_tag_index]

        expect(applied_tag_props["tagId"]).to eq applied_tag.tag_id
        expect(applied_tag_props["text"]).to eq applied_tag.tag.name
        expect(applied_tag_props["tagApproved"]).to eq applied_tag.approved?
      end
    end
  end
end
