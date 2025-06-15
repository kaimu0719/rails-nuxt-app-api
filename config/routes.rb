Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # users_controller
      resources :users, only: [:index]
    end
  end
end
