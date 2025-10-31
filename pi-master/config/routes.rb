require 'sidekiq/web'
require 'sidekiq-scheduler/web'

Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'auth/sessions',
    passwords: "auth/passwords",
  }

  namespace :admin do
    resources :accounts, only: [:new, :edit, :update, :create, :index, :destroy] do
      member do
        get :audit
        patch :deactivate
        patch :activate
        patch :block_qrvey_access
        patch :restore_qrvey_access
        patch :observe
        patch :register_with_qrvey
      end

      collection do
        get :audit_all
        get   :settings
        post  :update_settings
        patch :update_all_qrvey_access
      end

      resource :qrvey_user, only: [:show] do
        delete :delete_dashboard
      end
    end
    # get 'users/:id/login_as' => 'users#login_as', as: :login_as
    resources :users, only: [:index, :update, :destroy] do
      member do
        get :login_as
        post :add_account_link
        delete :remove_account_link
        patch :activate
        patch :deactivate
      end
    end

    resources :qrvey_dashboard_mappings, except: %i(new show edit) do
      member do
        post :change_position
      end
    end

    resources :prompt_templates

    resource :metadata, only: %i(create update destroy)

    resource :pdf_template_file_uploads, only: %i(destroy show) do
      post :upload
      patch :reorder_static_pdf_files
    end

    resource :surveys, only: [] do
      get :troubleshoot
      get :pdf_template
      get :metadata
      get :preview
      get :html_preview
    end

    get '/accounts/fetch_submissions' => 'accounts#fetch_submissions', as: :fetch_submissions
    post '/accounts/invite' => 'accounts#invite', as: :invite
    root 'accounts#index'
    resources :answers, only: [:index]

    get "/questions/" => "submissions#questions", as: :questions

    resource :submissions, only: [] do
      get :sample_generator
      post :sample_generator, action: :generate_samples
    end

    resources :survey_overview_documents, only: [:create, :update, :show] do
      member do
        get :presentation_url
        post :capture_screenshots
      end
    end



  end

  constraint = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.admin }
  constraints constraint do
    mount Sidekiq::Web => '/admin/sidekiq'
  end

  scope module: :auth do
    get 'sign_up' => 'registrations#new'
    post 'sign_up' => 'registrations#create'

    get 'saml_signin' => 'sessions#saml_signin'
    get 'initiate_saml' => 'sessions#initiate_saml'
    get 'sign_in' => 'sessions#new'
    get 'mfa_signin' => 'sessions#mfa_signin'
    patch 'complete_mfa' => 'sessions#complete_mfa'
    match 'logout' => 'sessions#destroy', via: [:get, :delete]

    # This is the "Authorized redirect URL" registered with Google for OAuth2.
    # Do not change or remove it without updating it in Google
    # TODO: Support arbitrary provider
    get 'auth/:provider/callback', to: 'sessions#omniauth'
    post 'auth/saml/:identify_provider_id/callback', to: 'sessions#omniauth'

    resource :email, only: %i(edit update)
  end

  scope module: :control do
    resource :mfa_settings
    resource :ai_agents, only: [:edit, :update]

    resources :scheduled_reports, only: [:index, :new, :edit, :create, :update, :destroy] do
      member do
        patch :pause
        patch :restart
      end
    end
    resources :automations, only: [:index, :new, :edit, :create, :update, :destroy]

    resources :ai_summarization_jobs, only: [:create, :show]
    resources :survey_brief_jobs, only: [:create, :show]

    resource :my_account, only: [:edit, :update] do
      get :audit
      get   :get_code_snippet
      get   :user_management
      match :data_integrations, via: [:get, :patch]
      get   :themes
      get   :global_targeting
      patch :update_email
      patch :update_password
      patch :update_global_targeting
      post  :update_frequency_capping
      patch :update_ai_summaries_enabled
    end

    get "account_dashboard" => "qrvey#dashboard_builder"
    resource :qrvey, only: [] do
      get "platform_health" => "qrvey#platform_health"
      get "client_reports" => "qrvey#client_reports"
      delete "delete_dashboard" => "qrvey#delete_dashboard"
      post "clone_dashboard" => "qrvey#clone_dashboard"
      put "share_dashboard" => "qrvey#share_dashboard"
      put "change_dashboard_permissions" => "qrvey#change_dashboard_permissions"
      post "create_dashboard" => "qrvey#create_dashboard"
    end

    post '/my_accounts/invite' => 'my_accounts#invite', as: :invite
    resource :personal_data_settings, only: %i(edit update)

    resources :questions, only: [:create, :update] do
      get :text_responses

      member do
        post :create_tag
        patch :update_tag
        delete :delete_tag
        patch :toggle_tag_automation_worker
        post :auto_tag_answers
        get :ai_tag_recommendations
      end
    end

    # TODO: Understand why this doesn't use "resources"
    resource :possible_answers, only: [] do
      member do
        patch ':id/update_settings' => 'possible_answers#update_settings', as: :update_settings
        patch ':id/remove_image' => 'possible_answers#remove_image', as: :remove_image
      end
    end

    resources :possible_answers, only: [] do
      member do
        patch :update_color
      end
    end

    resources :answer_images, only: [:create]

    resources :themes

    resources :tags do
      collection do
        post :bulk_add
        patch :bulk_approve
        delete :bulk_remove
      end
    end

    resources :applied_tags, only: [] do
      member do
        patch :approve
        delete :remove
      end

      collection do
        post :create_for_answers
        delete :remove_from_answers
      end
    end

    resources :tag_automation_jobs, only: [] do
      member do
        get :poll
      end
    end

    resources :surveys, except: :show do
      member do
        get :report
        get :background_report_stats
        get :background_report_metrics
        get :ajax_report
        post :duplicate
        post :inline_edit
        get :survey_deletion_modal
        get :survey_index_localization_modal
        delete :remove_background
        patch :change_status
        get :url_builder
        get '/questions/:question_id/free_text_answers' => 'surveys#free_text_answers', as: :question_free_text_answers
        get :trend_report_data
        get :page_event_data
        get :legacy_custom_card
        patch :localization_form_update
      end
      
      resources :recommendations, only: %i(index create), controller: 'survey_recommendations'
      resources :ai_outline_jobs, only: %i(index create show), controller: 'ai_outline_jobs' do
        collection do
          post :generate_gamma_presentation
          get :check_gamma_presentation_status
          post :download_gamma_presentation
        end
      end
    end

    resources :report_jobs, only: [:create] do
      member do
        get :status
      end
    end

    resources :survey_tags

    resources :users, only: [] do
      member do
        post :switch_accounts
      end
    end

    resources :page_events, only: :index do
      collection do
        delete :delete_all
      end
    end

    resources :custom_content_links, only: [] do
      member do
        patch :update_color
      end
    end

    resources :survey_locale_groups, only: [:create] do
      member do
        post :inline_edit
      end
    end

    get "locale_translation_caches/look_up/" => "locale_translation_caches#look_up"

    resources :question_locale_groups, only: [:update, :destroy]
    resources :possible_answer_locale_groups, only: [:create, :update, :destroy] do
      member do
        patch :update_color
      end
    end

    patch 'my_account/users/:id' => 'my_accounts#set_user_level', as: :set_user_level

    post 'live_preview' => 'surveys#live_preview', as: :live_preview

    get 'dashboard' => 'surveys#index', as: :dashboard

    get 'localization_editor_edit_possible_answer_locale_group_modal/' => 'possible_answer_locale_groups#localization_editor_edit_possible_answer_locale_group_modal', as: :localization_editor_edit_possible_answer_locale_group_modal

    get 'localization_editor_survey_modal/' => 'surveys#localization_editor_survey_modal', as: :localization_editor_survey_modal
    get 'localization_editor/:survey_locale_group_id' => 'surveys#localization_editor', as: :localization_editor
    post 'localization_editor/:survey_locale_group_id' => 'surveys#localization_update', as: :localization_update
    post 'localization_editor/:survey_locale_group_id/content_update' => 'surveys#localization_content_update', as: :localization_content_update
    post 'localization_editor/:survey_locale_group_id/base_update' => 'surveys#localization_base_update', as: :localization_base_update
    post 'localization_duplicate/:survey_locale_group_id' => 'surveys#localization_duplicate', as: :localization_duplicate

    get 'localization_report/:survey_locale_group_id' => 'surveys#localization_report', as: :localization_report
    get 'localization_report_stats/:survey_locale_group_id' => 'surveys#localization_report_stats', as: :localization_report_stats
    get 'localization_report_metrics/:survey_locale_group_id' => 'surveys#localization_report_metrics', as: :localization_report_metrics

    get 'localization_editor_new_possible_answer_modal/' => 'possible_answers#localization_editor_new_possible_answer_modal', as: :localization_editor_new_possible_answer_modal
    get 'localization_editor_possible_answer_image_modal/' => 'possible_answers#localization_editor_possible_answer_image_modal', as: :localization_editor_possible_answer_image_modal

    get 'localization_editor_new_base_question_modal/' => 'questions#localization_editor_new_base_question_modal', as: :localization_editor_new_base_question_modal

    get 'localization_editor_edit_base_question_modal/' => 'question_locale_groups#localization_editor_edit_base_question_modal', as: :localization_editor_edit_base_question_modal
  end

  post 'upload' => 'uploads#create'

  # Rack app
  pi_rack_app = Rack::Pi.new
  get '/serve', :to => pi_rack_app
  get '/direct_serve', :to => pi_rack_app
  get '/heartbeat', :to => pi_rack_app
  get '/surveys/:id/questions', :to => pi_rack_app
  get '/surveys/:id', :to => pi_rack_app
  get '/surveys/:id/poll', :to => pi_rack_app
  get '/submissions/:id/viewed_at', :to => pi_rack_app
  get '/submissions/email_answer', :to => pi_rack_app
  get '/submissions/:id/answer', :to => pi_rack_app
  get '/submissions/:id/all_answers', :to => pi_rack_app
  get '/submissions/:id/close', :to => pi_rack_app
  get '/q/:question_id/a/:answer_id', :to => pi_rack_app
  get '/q/:question_id', :to => pi_rack_app
  get '/devices/:udid/set_data', :to => pi_rack_app
  get '/results', :to => pi_rack_app
  get '/present_results', :to => pi_rack_app
  get '/track_event', :to => pi_rack_app
  get '/custom_content_link_click', :to => pi_rack_app

  get '404', to: 'errors#not_found'
  get '422', to: 'errors#unacceptable'
  get '500', to: 'errors#internal_error'

  root 'auth/sessions#new'

  match '*any_other', to: redirect('404'), via: :all unless Rails.env.development?

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
