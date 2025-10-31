# frozen_string_literal: true
module Control
  class AIAgentsController < BaseController
    before_action :require_full_access_user!

    def edit
      presenter = AIAgentsPresenter.new(current_account)

      @ai_agents = presenter.ai_agents
    end

    def update
      current_account.update(ai_agent_params)

      redirect_to edit_ai_agents_path
    end

    private

    def ai_agent_params
      params.permit(current_account.ai_agent_feature_flags.keys.map(&:to_sym))
    end
  end
end
