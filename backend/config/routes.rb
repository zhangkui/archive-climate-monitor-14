Rails.application.routes.draw do
  root to: proc { [200, { "content-type" => "application/json" },
                    ['{"service":"archive-vault","status":"ok"}']] }

  scope :api do
    # 设备数据接入
    post "ingest", to: "ingest#create"
    post "device-events", to: "ingest#device_event"

    # 实时看板与查询
    get  "dashboard", to: "dashboard#index"
    get  "zones", to: "zones#index"
    get  "zones/:id", to: "zones#show"
    get  "zones/:id/series", to: "zones#series"
    get  "zones/:id/history", to: "zones#history"
    post "zones/:id/boundary", to: "zones#change_boundary"
    post "zones/:id/merge", to: "zones#merge"

    resources :sensors, only: [:index, :create, :update]
    post "sensors/:id/replace", to: "sensors#replace"

    # 风险规则（版本化）
    resources :risk_rules, path: "rules", only: [:index, :show, :create] do
      member do
        post :activate
      end
    end

    # 风险事件
    resources :risk_events, path: "events", only: [:index, :show] do
      member do
        post :confirm
        post :resolve
      end
    end

    # 审计
    resources :audit_events, path: "audit", only: [:index, :show]

    # 报表（CSV 存 MinIO，返回预签名 URL）
    resources :reports, only: [:index, :create, :show]
    get  "reports/:id/download", to: "reports#download"
  end

  get "*path", to: proc { [404, { "content-type" => "application/json" },
                           ['{"error":"not_found"}']] }
end
