class ApplicationController < ActionController::API
  # ActionController::Cookiesをincludeして、Cookieの操作を可能にする
  #【cookiesメソッドについて】https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html
  include ActionController::Cookies

  before_action :require_login, :xhr_request?

  private

    def current_user
      current_user ||= User.from_access_token(request.headers["Authorization"]&.split&.last)
      rescue UserAuth.not_found_exception_class, JWT::DecodeError, JWT::EncodeError
      nil
    end

    def logged_in?
      (current_user.present? && current_user.activated?)
    end

    def require_login
      if !logged_in?
        cookies.delete(UserAuth.session_key)

        head(:unauthorized)
      end
    end

    def xhr_request?
      # リクエストヘッダー X-Requested-With: 'XMLHttpRequest' の存在を判定
      return if request.xml_http_request?
      render status: :forbidden, json: { status: 403, error: 'Forbidden' }
    end

    # サーバーエラーのレスポンスを返す
    def response_500(msg = "Internal Server Error")
      render status: :internal_server_error, json: { status: 500, error: msg }
    end
end
