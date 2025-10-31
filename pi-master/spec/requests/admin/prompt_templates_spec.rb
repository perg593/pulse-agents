# frozen_string_literal: true

require 'spec_helper'

describe "Admin::PromptTemplates" do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) { create(:admin) }
  let(:regular_user) { create(:user) }

  before do
    sign_in admin_user
  end

  describe "GET /admin/prompt_templates" do
    it "returns a success response" do
      create(:prompt_template)

      get admin_prompt_templates_path

      expect(response).to be_successful
    end

    it "lists all prompt templates" do
      create(:prompt_template, name: "Template 1")
      create(:prompt_template, name: "Template 2")

      get admin_prompt_templates_path

      expect(response.body).to include("Template 1")
      expect(response.body).to include("Template 2")
    end
  end

  describe "GET /admin/prompt_templates/:id" do
    it "returns a success response" do
      prompt_template = create(:prompt_template)

      get admin_prompt_template_path(prompt_template)

      expect(response).to be_successful
    end
  end

  describe "GET /admin/prompt_templates/new" do
    it "returns a success response" do
      get new_admin_prompt_template_path

      expect(response).to be_successful
    end
  end

  describe "GET /admin/prompt_templates/:id/edit" do
    it "returns a success response" do
      prompt_template = create(:prompt_template)

      get edit_admin_prompt_template_path(prompt_template)

      expect(response).to be_successful
    end
  end

  describe "POST /admin/prompt_templates" do
    context "with valid params" do
      it "creates a new PromptTemplate" do
        expect do
          post admin_prompt_templates_path, params: { prompt_template: attributes_for(:prompt_template) }
        end.to change(PromptTemplate, :count).by(1)
      end

      it "redirects to the created prompt template" do
        post admin_prompt_templates_path, params: { prompt_template: attributes_for(:prompt_template) }
        expect(response).to redirect_to(admin_prompt_template_path(PromptTemplate.last))
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'new' template)" do
        post admin_prompt_templates_path, params: { prompt_template: { name: nil, content: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PUT /admin/prompt_templates/:id" do
    context "with valid params" do
      let(:new_attributes) do
        {
          name: "Updated Template",
          content: "Updated content"
        }
      end

      it "updates the requested prompt template" do
        prompt_template = create(:prompt_template)

        put admin_prompt_template_path(prompt_template), params: { prompt_template: new_attributes }

        prompt_template.reload
        expect(prompt_template.name).to eq("Updated Template")
      end

      it "redirects to the prompt template" do
        prompt_template = create(:prompt_template)

        put admin_prompt_template_path(prompt_template), params: { prompt_template: new_attributes }

        expect(response).to redirect_to(admin_prompt_template_path(prompt_template))
      end
    end

    context "with invalid params" do
      it "returns a success response (i.e. to display the 'edit' template)" do
        prompt_template = create(:prompt_template)

        put admin_prompt_template_path(prompt_template), params: { prompt_template: { name: nil, content: nil } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/prompt_templates/:id" do
    it "destroys the requested prompt template" do
      prompt_template = create(:prompt_template)

      expect do
        delete admin_prompt_template_path(prompt_template)
      end.to change(PromptTemplate, :count).by(-1)
    end

    it "redirects to the prompt templates list" do
      prompt_template = create(:prompt_template)

      delete admin_prompt_template_path(prompt_template)

      expect(response).to redirect_to(admin_prompt_templates_path)
    end
  end

  describe "authorization" do
    context "when user is not admin" do
      before do
        sign_in regular_user
      end

      it "denies access to index" do
        get admin_prompt_templates_path

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to show" do
        prompt_template = create(:prompt_template)

        get admin_prompt_template_path(prompt_template)

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to new" do
        get new_admin_prompt_template_path

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to edit" do
        prompt_template = create(:prompt_template)

        get edit_admin_prompt_template_path(prompt_template)

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to create" do
        post admin_prompt_templates_path, params: { prompt_template: attributes_for(:prompt_template) }

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to update" do
        prompt_template = create(:prompt_template)

        put admin_prompt_template_path(prompt_template), params: { prompt_template: { name: "Updated" } }

        expect(response).to redirect_to(dashboard_path)
      end

      it "denies access to destroy" do
        prompt_template = create(:prompt_template)

        delete admin_prompt_template_path(prompt_template)

        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
