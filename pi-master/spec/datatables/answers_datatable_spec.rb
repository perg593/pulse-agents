# frozen_string_literal: true
require 'spec_helper'

describe AnswersDatatable do
  describe "Answer destruction" do
    context "when instantiated with answer IDs" do
      before do
        @answer_ids = [1, 2, 3]

        @view = Object.new
        allow(@view).to receive(:params).and_return({answer_ids: @answer_ids})

        @answer_ids.each { |answer_id| create(:answer, id: answer_id) }
      end

      it "destroys the answers having the provided IDs" do
        described_class.new(@view, nil, nil)

        expect(Answer.where(id: @answer_ids).count).to be(0)
      end
    end
  end
end
