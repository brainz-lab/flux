Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API endpoints
  namespace :api do
    namespace :v1 do
      # Events
      post "events", to: "events#create"
      post "events/batch", to: "events#batch"
      get "events", to: "events#index"
      get "events/count", to: "events#count"
      get "events/stats", to: "events#stats"
      get "events/:id", to: "events#show"

      # Metrics
      post "metrics", to: "metrics#create"
      post "metrics/batch", to: "metrics#batch"
      get "metrics", to: "metrics#index"
      get "metrics/:name", to: "metrics#show", constraints: { name: /[^\/]+/ }
      get "metrics/:name/query", to: "metrics#query", constraints: { name: /[^\/]+/ }

      # Dashboards
      resources :dashboards, param: :id do
        resources :widgets
      end

      # Anomalies
      get "anomalies", to: "anomalies#index"
      get "anomalies/:id", to: "anomalies#show"
      post "anomalies/:id/acknowledge", to: "anomalies#acknowledge"
      post "anomalies/acknowledge_all", to: "anomalies#acknowledge_all"

      # Batch ingestion (events + metrics)
      post "flux/batch", to: "batch#create"
    end
  end

  # MCP Server endpoints
  namespace :mcp do
    get "tools", to: "tools#index"
    post "tools/:name", to: "tools#call"
    post "rpc", to: "tools#rpc"
  end

  # Dashboard (web UI)
  namespace :dashboard do
    root to: "projects#index"

    resources :projects, only: [:index, :new, :create] do
      member do
        get :settings
      end

      # Nested under project
      get "/", to: "overview#index", as: :overview
      resources :events, only: [:index, :show]
      resources :metrics, only: [:index, :show]
      resources :dashboards do
        resources :widgets
      end
      resources :anomalies, only: [:index, :show] do
        member do
          post :acknowledge
        end
      end
      get "setup", to: "setup#index"
      get "mcp", to: "mcp_setup#index"
      get "dev_tools", to: "dev_tools#index"
    end
  end

  # SSO callback
  get "sso/callback", to: "sso#callback"
  delete "sso/logout", to: "sso#logout"

  # Root redirect to dashboard
  root to: redirect("/dashboard")
end
