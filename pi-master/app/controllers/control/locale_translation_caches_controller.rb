# frozen_string_literal: true
module Control
  class LocaleTranslationCachesController < BaseController
    def look_up
      translation_cache = LocaleTranslationCache.find_by(
        record_id: params[:record_id],
        record_type: params[:record_type],
        column: params[:column]
      )

      if translation_cache
        if translation_cache.account != current_user.account
          redirect_to dashboard_path and return
        end

        render json: { translation: translation_cache.translation }, status: :ok and return
      else
        Rollbar.warning("No translation found", record_id: params[:record_id], record_type: params[:record_type], column: params[:column])
        render json: { error: "error retrieving translation -- contact admin for details" }, status: :not_found and return
      end
    end
  end
end
