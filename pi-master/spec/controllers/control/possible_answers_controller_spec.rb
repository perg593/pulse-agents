# frozen_string_literal: true
require 'spec_helper'

describe Control::PossibleAnswersController do
  describe "PATCH #update_color" do
    let(:user) { create(:user) }
    let(:old_color) { "#00f" }
    let(:survey) { create(:survey, account: user.account) }
    let(:valid_color) { "#f00" }
    let(:record) do
      possible_answer = survey.possible_answers.first
      possible_answer.update(report_color: old_color)
      possible_answer
    end

    include_examples "color update"
  end
end
