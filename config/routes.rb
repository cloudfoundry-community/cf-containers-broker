CfContainersBroker::Application.routes.draw do
  namespace :v2 do
    resource :catalog, only: [:show]
    resources :service_instances, only: [:update, :patch, :destroy] do
      resources :service_bindings, only: [:update, :destroy]
    end
  end

  namespace :manage do
    get 'auth/cloudfoundry/callback' => 'auth#create'
    get 'auth/failure'               => 'auth#failure'
    get 'instances/:service_guid/:plan_guid/:instance_guid' => 'instances#show', :as => :instance
  end
end
