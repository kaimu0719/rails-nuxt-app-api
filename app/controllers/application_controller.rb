class ApplicationController < ActionController::API
  # ActionController::Cookiesをincludeして、Cookieの操作を可能にする
  #【cookiesメソッドについて】https://api.rubyonrails.org/classes/ActionDispatch/Cookies.html
  include ActionController::Cookies

  # 認可を行う
  include UserAuthenticateService

  # CSRF対策
  # 全てのアクションが実行される前に、リクエストヘッダーが、
  # X-Requested-With: 'XMLHttpRequest' であることを確認する
  # XMLHttpRequestリクエストでない場合は、403 Forbiddenを返す
  #
  # これで得られるCSRF対策
  # - 悪意のあるサイトからのリクエストを防ぐ（別オリジンのサイトからはカスタムヘッダーを送信できないため）
  before_action :xhr_request?

  private
    # XHRリクエストかどうかを確認する
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
