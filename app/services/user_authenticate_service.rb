# このモジュールは、リクエストヘッダーのAuthorizationに含まれるアクセストークンを使用して、
# ユーザーが取得できるかどうかを判断するためモジュールである。
# ApplicationControllerにincludeしてコントローラー上で、
# ユーザーの認証を行うために使用される。
module UserAuthenticateService

  # Cookieのaccess_tokenの値を元にユーザー情報が取得できた場合はtrueを返す。
  # 取得できない場合は、401 Unauthorizedを返す。
  def authenticate_user
    current_user.present? || unauthorized_user
  end

  # Cookieのaccess_tokenの値を元にユーザー情報が取得できる、かつ、
  # ユーザーがアクティブな状態（activated?がtrue）
  # の場合はtrueを返す。
  # 取得できない場合や、ユーザーがアクティブでない場合は、401 Unauthorizedを返す。
  def authenticate_active_user
    (current_user.present? && current_user.activated?) || unauthorized_user
  end

  private

    # リクエストヘッダートークンを取得する
    # requestは ActionDispatch::Request オブジェクト
    # Authorization リクエストヘッダーには access_token が含まれている
    def token_from_request_headers
      # リクエストヘッダーにAuthorizationが存在する場合は、アクセストークンを取得
      # Authorizationが存在しない場合はnilを返す
      request.headers["Authorization"]
    end

    # access_tokenから有効なユーザーを取得する
    def fetch_user_from_access_token
      # TokenGenerateService【Userモデルにincludeされている】モジュールのクラスメソッドを使用して、
      # リクエストヘッダーから取得したアクセストークンをもとにユーザーエンティティを取得する
      User.from_access_token(token_from_request_headers)
    
    # アクセストークンからユーザーが取得できない場合は、以下の例外を処理する
    rescue UserAuth.not_found_exception_class,
           JWT::DecodeError, JWT::EncodeError
      nil
    end

    # tokenのユーザーを返す
    def current_user
      # リクエストヘッダーのAuthorizationがnilの場合はnilを返す
      return nil unless token_from_request_headers

      # アクセストークンからユーザーを取得し、インスタンス変数にキャッシュする
      # これにより、同じリクエスト内で何度もデコードする必要がなくなる
      # @_はインスタンス変数がクラス内部でしか使用されないことを示す
      @_current_user ||= fetch_user_from_access_token
    end

    # 認証エラーが発生した場合の処理
    def unauthorized_user
      # クッキーからリフレッシュトークンを削除
      cookies.delete(UserAuth.session_key)

      # 401 Unauthorized ステータスコードを返す。
      # head => ActionController::Head.headメソッドは、HTTPレスポンスのヘッダーのみを返す。
      head(:unauthorized)
    end
end
