# frozen_string_literal: true

require 'spec_helper'

describe Automation do
  it 'is not valid without an action' do
    automation = build(:automation_with_condition)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(actions: [{ error: :too_short, count: 1 }])
  end

  it 'is not valid without a condition' do
    automation = build(:automation_with_action)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(conditions: [{ error: :too_short, count: 1 }])
  end

  it 'is not valid without a name' do
    automation = build(:automation_with_condition_and_action, name: nil)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(name: [{ error: :blank }])
  end

  it 'is not valid without a condition_type' do
    automation = build(:automation_with_condition_and_action, condition_type: nil)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(condition_type: [{ error: :blank }])
  end

  it 'is not valid without an action_type' do
    automation = build(:automation_with_condition_and_action, action_type: nil)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(action_type: [{ error: :blank }])
  end

  it 'is not valid if condition_type and action_type is not matched' do
    automation = build(:automation_with_condition_and_action, condition_type: :url, action_type: :send_email)
    expect_an_error_attribute(automation)
    expect(automation.errors.details).to eq(base: [{ error: 'condition_type and action_type not matching' }])
  end

  it 'can be valid' do
    automation = build(:automation_with_condition_and_action)

    expect(automation.valid?).to be true
  end

  def expect_an_error_attribute(automation)
    expect(automation.valid?).to be false
    expect(automation.errors.count).to eq 1
  end
end
