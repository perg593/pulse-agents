# frozen_string_literal: true
require 'spec_helper'

describe ScheduledTagAutomationWorker do
  it 'creates TagAutomationJob for each eligible question' do
    ineligible_question = create(:free_text_question)
    eligible_question = create(:free_text_question, tag_automation_worker_enabled: true)
    eligible_question.tags << create(:tag)

    described_class.new.perform

    expect(ineligible_question.reload.tag_automation_jobs.count).to eq 0
    expect(eligible_question.reload.tag_automation_jobs.count).to eq 1
  end
end
