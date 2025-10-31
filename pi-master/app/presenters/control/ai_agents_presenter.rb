# frozen_string_literal: true
module Control
  class AIAgentsPresenter
    def initialize(account)
      @account = account
    end

    def ai_agents
      @account.ai_agent_feature_flags.map do |column_name, enabled|
        {
          id: column_name,
          name: column_name.delete_suffix("_agent_enabled").titleize,
          enabled: enabled
        }
      end
    end
  end
end
