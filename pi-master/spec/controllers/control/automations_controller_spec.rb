# frozen_string_literal: true

require 'spec_helper'

describe Control::AutomationsController do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  let(:email) { 'test@test.com' }
  let(:event_name) { 'test event' }
  let(:event_properties) { { test: 1 }.to_json }

  before do
    sign_in user
  end

  describe "Automation requirement" do
    it "redirects to the survey dashboard when the automation is not found" do
      sign_in create(:user)

      endpoints = [
        { verb: :get, url: :edit },
        { verb: :patch, url: :update },
        { verb: :delete, url: :destroy }
      ]

      endpoints.each do |endpoint|
        it_handles_missing_records(endpoint)
      end
    end
  end

  describe "POST #create" do
    context 'when it is "answer_text" type' do
      it "creates an Automation object with the right answer text and email" do
        question = create(:survey, account: account).questions.first

        expect do
          post :create, params:
            { automation:
              { name: 'test event', enabled: true, condition_type: 'answer_text', action_type: 'send_email',
                conditions_attributes: { '0': { question_id: question.id, condition: 'test_condition' } },
                actions_attributes: { '0': { email: ['', email] } }
              }
            }
        end.to change { Automation.count }.from(0).to(1)

        automation = Automation.first
        expect(automation.conditions.count).to eq 1
        expect(automation.actions.count).to eq 1
        expect(automation.conditions.first.question).to eq question
        expect(automation.actions.first.email).to eq email
      end

      it "doesn't create an Automation object if a question doesn't belong to the same account" do
        random_question = create(:survey).questions.first

        expect do
          post :create, params:
            { automation:
                { name: 'test event', enabled: true, condition_type: 'answer_text', action_type: 'send_email',
                  conditions_attributes: { '0': { question_id: random_question.id, condition: 'test_condition' } },
                  actions_attributes: { '0': { email: ['', email] } }
                }
            }
        end.not_to change { Automation.count }
      end
    end

    context 'when it is "url" type' do
      it "creates an Automation object with the right url condition and event attributes" do
        url_matcher = 'url_contains'

        expect do
          post :create, params:
            { automation:
              { name: 'test event', enabled: true, condition_type: 'url', action_type: 'create_event',
                conditions_attributes: { '0': { url_matcher: url_matcher, condition: 'test' } },
                actions_attributes: { '0': { event_name: event_name, event_properties: event_properties } }
              }
            }
        end.to change { Automation.count }.from(0).to(1)

        automation = Automation.first
        expect(automation.conditions.count).to eq 1
        expect(automation.actions.count).to eq 1
        expect(automation.conditions.first.url_matcher).to eq url_matcher
        expect(automation.actions.first.event_name).to eq event_name
        expect(automation.actions.first.event_properties).to eq event_properties
      end

      it "doesn't create an Automation object if there is more than 1 condition" do
        expect do
          post :create, params:
            { automation:
                { name: 'test event', enabled: true, condition_type: 'url', action_type: 'create_event',
                  conditions_attributes: { '0': { url_matcher: :url_is, condition: 'test' }, '1': { url_matcher: :url_contains, condition: 'test2' } },
                  actions_attributes: { '0': { event_name: 'test event', event_properties: { test: 1 }.to_json } }
                }
            }
        end.not_to change { Automation.count }
      end

      it "doesn't create an Automation object if there is more than 1 action" do
        expect do
          post :create, params:
            { automation:
                { name: 'test event', enabled: true, condition_type: 'url', action_type: 'create_event',
                  conditions_attributes: { '0': { url_matcher: :url_is, condition: 'test' } },
                  actions_attributes: { '0': { event_name: 'test event', event_properties: { test: 1 }.to_json },
                                        '1': { event_name: 'test event2', event_properties: { test: 2 }.to_json } }
                }
            }
        end.not_to change { Automation.count }
      end
    end
  end

  describe "PATCH #update" do
    context 'when it is "answer_text" type' do
      let(:automation) { create(:automation_with_condition_and_action, account: account) }

      it "updates an Automation object with the right answer text and email" do
        question = create(:survey, account: account).questions.first

        expect(automation.conditions.first.question).not_to eq question
        expect(automation.actions.first.email).not_to eq email
        patch :update, params:
          { id: automation.id, automation:
            {
              conditions_attributes: { '0': { question_id: question.id, condition: 'test' } },
              actions_attributes: { '0': { email: ['', email] } }
            }
          }
        automation.reload
        expect(automation.conditions.first.question).to eq question
        expect(automation.actions.first.email).to eq email
      end

      it "doesn't update an Automation object if a question doesn't belong to the same account" do
        random_question = create(:question)

        patch :update, params:
          { id: automation.id, automation:
            {
              conditions_attributes: { '0': { question_id: random_question.id, condition: 'test' } },
              actions_attributes: { '0': { email: ['', email] } }
            }
          }

        expect(automation.conditions.first.question).not_to eq random_question
        expect(automation.actions.first.email).not_to eq email
      end
    end

    context 'when it is "url" type' do
      let(:automation) { create(:automation_with_condition_and_action, condition_type: :url, action_type: :create_event, account: account) }
      let(:url_matcher) { 'url_contains' }

      it "updates an Automation object with the right url condition and event attributes" do
        expect(automation.conditions.first.url_matcher).not_to eq url_matcher
        expect(automation.actions.first.event_name).not_to eq event_name
        expect(automation.actions.first.event_properties).not_to eq event_properties
        patch :update, params:
          { id: automation.id, automation:
            {
              conditions_attributes: { '0': { url_matcher: url_matcher, condition: 'test' } },
              actions_attributes: { '0': { event_name: event_name, event_properties: event_properties } }
            }
          }
        automation.reload
        expect(automation.conditions.first.url_matcher).to eq url_matcher
        expect(automation.actions.first.event_name).to eq event_name
        expect(automation.actions.first.event_properties).to eq event_properties
      end

      it "doesn't update an Automation object if there is more than 1 condition" do
        expect(automation.conditions.first.url_matcher).not_to eq url_matcher
        expect(automation.actions.first.event_name).not_to eq event_name
        expect(automation.actions.first.event_properties).not_to eq event_properties
        patch :update, params:
          { id: automation.id, automation:
            {
              conditions_attributes: { '0': { url_matcher: url_matcher, condition: 'test' }, '1': { url_matcher: :url_contains, condition: 'test2' } },
              actions_attributes: { '0': { event_name: event_name, event_properties: event_properties } }
            }
          }
        automation.reload
        expect(automation.conditions.first.url_matcher).not_to eq url_matcher
        expect(automation.actions.first.event_name).not_to eq event_name
        expect(automation.actions.first.event_properties).not_to eq event_properties
      end

      it "doesn't update an Automation object if there is more than 1 action" do
        expect(automation.conditions.first.url_matcher).not_to eq url_matcher
        expect(automation.actions.first.event_name).not_to eq event_name
        expect(automation.actions.first.event_properties).not_to eq event_properties
        patch :update, params:
          { id: automation.id, automation:
            {
              conditions_attributes: { '0': { url_matcher: url_matcher, condition: 'test' } },
              actions_attributes: { '0': { event_name: event_name, event_properties: event_properties },
                                    '1': { event_name: 'test event2', event_properties: { test: 2 }.to_json } }
            }
          }
        automation.reload
        expect(automation.conditions.first.url_matcher).not_to eq url_matcher
        expect(automation.actions.first.event_name).not_to eq event_name
        expect(automation.actions.first.event_properties).not_to eq event_properties
      end
    end
  end
end
