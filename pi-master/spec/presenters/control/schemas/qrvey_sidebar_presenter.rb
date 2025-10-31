# frozen_string_literal: true

module Schemas
  module QrveySidebarPresenter
    LinkSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:text).value(:string)
      required(:url).value(:string)
      optional(:editModeUrl).value(:string)
      required(:current).value(:bool)
      optional(:additionalClasses).value(:string)
      required(:dashboardId) { nil? | str? }
    end

    LinksSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:builtIn).value(Dry.Types::Array.of(LinkSchema))
      required(:myReports).value(Dry.Types::Array.of(LinkSchema))
      required(:sharedWithMe).value(Dry.Types::Array.of(LinkSchema))
    end

    AuthorizationSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:canCopy).value(:bool)
      required(:canDelete).value(:bool)
      required(:canShare).value(:bool)
      required(:canEdit).value(:bool)
    end

    ShareOptionSchema = Dry::Schema.JSON do
      config.validate_keys = true

      required(:userName).value(:string)
      required(:userId).value(:integer)
      required(:shared).value(:bool)
      required(:permissions) { nil? | int? }
    end

    # No support for dynamic keys yet :(
    ShareOptionsSchema = Dry::Schema.JSON do
      # (:some_qrvey_dashboard_id).value(Dry.Types::Array.of(ShareOptionSchema)))
      # (:some_other_qrvey_dashboard_id).value(Dry.Types::Array.of(ShareOptionSchema)))
      # ...
      # (:yet_another_qrvey_dashboard_id).value(Dry.Types::Array.of(ShareOptionSchema)))
    end
  end
end
