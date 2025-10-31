# frozen_string_literal: true
require 'spec_helper'

describe Control::TagsController do
  let(:account) { create(:account) }
  let(:survey) { create(:survey, account: account) }

  before do
    sign_in create(:user, account: account)

    @question = create(:question, question_type: :free_text_question, survey: survey)
    @answer = create(:answer, question: @question, text_answer: 'test')
    @answer2 = create(:answer, question: @question, text_answer: 'test2')
  end

  describe 'POST #bulk_add' do
    it_behaves_like "shared authorization" do
      def make_call
        @tag = create(:tag, question: @question, name: 'test name', color: 'test color')

        post :bulk_add, params: { question_id: @question.id, tag_name: @tag.name, answer_ids: [@answer.id, @answer2.id] }
      end
    end

    context 'when the specified tag exists' do
      before do
        @tag = create(:tag, question: @question, name: 'test name', color: 'test color')
      end

      it 'creates applied tags with the specified tag' do
        post :bulk_add, params: { question_id: @question.id, tag_name: @tag.name, answer_ids: [@answer.id, @answer2.id] }

        expect(AppliedTag.count).to eq 2

        response_tags = JSON.parse(response.body).deep_symbolize_keys[:response]

        expect(response_tags.length).to eq 2

        [@answer, @answer2].each_with_index { |answer, i| assert_expected_response_tag(response_tags[i], answer, @tag) }
      end

      context 'when a specified tag does not exist' do
        it 'creates a new tag, then creates applied tags with it' do
          new_name = 'new tag name'
          expect(Tag.find_by(question: @question, name: new_name)).to be_nil

          post :bulk_add, params: { question_id: @question.id, tag_name: new_name, answer_ids: [@answer.id, @answer2.id] }
          expect(Tag.find_by(question: @question, name: new_name)).not_to be_nil

          response_tags = JSON.parse(response.body).deep_symbolize_keys[:response]

          expect(response_tags.length).to eq 2

          new_tag = Tag.find_by(question: @question, name: new_name)

          [@answer, @answer2].each_with_index { |answer, i| assert_expected_response_tag(response_tags[i], answer, new_tag) }
        end
      end

      def assert_expected_response_tag(response_tag, answer, tag)
        expect(response_tag.keys).to contain_exactly(:answerId, :appliedTags)

        expect(response_tag[:answerId]).to eq answer.id
        expect(response_tag[:appliedTags].length).to eq answer.applied_tags.count

        response_tag[:appliedTags].each { |applied_tag| assert_expected_applied_tag(applied_tag, answer, tag) }
      end

      def assert_expected_applied_tag(applied_tag, answer, tag)
        expect(applied_tag.keys).to contain_exactly(:tagId, :text, :tagApproved, :appliedTagId, :tagColor)

        expect(applied_tag[:tagId]).to eq tag.id
        expect(applied_tag[:text]).to eq tag.name
        expect(applied_tag[:tagApproved]).to be true
        expect(applied_tag[:appliedTagId]).to eq answer.applied_tags.first.id
      end
    end

    describe 'POST #bulk_approve' do
      it_behaves_like "shared authorization" do
        def make_call
          patch :bulk_approve, params: { answer_ids: [@answer.id, @answer2.id] }
        end
      end

      it 'approves tags associated with the selected answers' do
        tag = create(:tag, question: @question)
        applied_tag = create(:automatically_applied_tag, tag: tag, answer: @answer, is_good_automation: false)
        tag2 = create(:tag, question: @question)
        applied_tag2 = create(:automatically_applied_tag, tag: tag2, answer: @answer2, is_good_automation: false)

        patch :bulk_approve, params: { answer_ids: [@answer.id, @answer2.id] }

        expect(applied_tag.reload.is_good_automation).to be true
        expect(applied_tag2.reload.is_good_automation).to be true

        response_tags = JSON.parse(response.body).deep_symbolize_keys[:tags]
        expect(response_tags).to contain_exactly(
          { answer_id: @answer.id, applied_tag_id: applied_tag.id },
          { answer_id: @answer2.id, applied_tag_id: applied_tag2.id }
        )
      end
    end

    describe 'POST #bulk_remove' do
      before do
        @tag = create(:tag, question: @question)
        @applied_tag = create(:applied_tag, tag: @tag, answer: @answer)

        @tag2 = create(:tag, question: @question)
        @applied_tag2 = create(:applied_tag, tag: @tag2, answer: @answer2)
      end

      it_behaves_like "shared authorization" do
        def make_call
          delete :bulk_remove, params: { question_id: @question.id, tag_name: @tag.name, answer_ids: [@answer.id, @answer2.id] }
        end
      end

      context 'when a tag name is specified' do
        it 'removes the specific tag from the selected answers' do
          delete :bulk_remove, params: { question_id: @question.id, tag_name: @tag.name, answer_ids: [@answer.id, @answer2.id] }

          expect(AppliedTag.find_by(id: @applied_tag.id)).to be_nil
          expect(AppliedTag.find_by(id: @applied_tag2.id)).not_to be_nil

          response_tags = JSON.parse(response.body).deep_symbolize_keys[:tags]

          expect(response_tags).to contain_exactly(
            { answer_id: @answer.id, applied_tag_id: @applied_tag.id }
          )
        end
      end

      context 'when a tag name is not specified' do
        it 'removes any tags from the selected answers' do
          delete :bulk_remove, params: { question_id: @question.id, answer_ids: [@answer.id, @answer2.id] }

          expect(AppliedTag.find_by(id: @applied_tag.id)).to be_nil
          expect(AppliedTag.find_by(id: @applied_tag2.id)).to be_nil

          response_tags = JSON.parse(response.body).deep_symbolize_keys[:tags]

          expect(response_tags).to contain_exactly(
            { answer_id: @answer.id, applied_tag_id: @applied_tag.id },
            { answer_id: @answer2.id, applied_tag_id: @applied_tag2.id }
          )
        end
      end
    end
  end
end
