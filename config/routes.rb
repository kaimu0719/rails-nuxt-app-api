Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # users_controller
      resources :users, only: [:index]

      # auth_token_controller
      resources :auth_token, only: [:create] do
        # /auth_token/refresh, auth_token/destroyのルーティングを追加
        collection do
          post :refresh
          delete :destroy
        end
      end
    end
  end
end
