# このモジュールは、ブラウザ側で保持しているログインセッション情報（リフレッシュトークン「JWT」）を
# コントローラー側で管理するための共通ロジックである
# コントローラー側では、
#  - リフレッシュトークンからユーザーを取得する sessionize_user メソッド
#  - リフレッシュトークンを取得する session_key メソッド
#  - Cookieに保持されているリフレッシュトークンを削除する delete_session メソッド
# を提供する
module UserSessionizeService

  # セッションユーザーが居ればtrue、存在しない場合は401を返す
  def sessionize_user
    session_user.present? || unauthorized_user
  end

  # セッションキー
  def session_key
    UserAuth.session_key
  end

  # セッションcookieを削除する
  def delete_session
    cookies.delete(session_key)
  end

  private

    # cookieのtokenを取得
    def token_from_cookies
      cookies[session_key]
    end

    # refresh_tokenから有効なユーザーを取得する
    def fetch_user_from_refresh_token
      # UserモデルのTokenGenerateServiceモジュールのクラスメソッドを使用して、
      # リフレッシュトークンをデコードし、ユーザーエンティティを取得する
      User.from_refresh_token(token_from_cookies)
    rescue JWT::InvalidJtiError
      # jtiエラーの場合はcontrollerに処理を委任
      # ここでの処理は、リフレッシュトークンが無効であり、JWT ID (jti)が不正であることを示す
      # そのため、セッションを削除し、JWT::InvalidJtiErrorを発生させる
      catch_invalid_jti

    # アクセストークンからユーザーが取得できない場合は、以下の例外を処理する
    # UserAuth.not_found_exception_classは、Userモデルで定義されている404エラーのクラスである
    rescue UserAuth.not_found_exception_class,
           JWT::DecodeError, JWT::EncodeError
      nil
    end

    # refresh_tokenのユーザーを返す
    def session_user
      # Cookieからリフレッシュトークンが存在しない場合はnilを返し、未ログインであることを示す。
      return nil unless token_from_cookies

      # リフレッシュトークンからユーザーを取得し、インスタンス変数にキャッシュする
      @_session_user ||= fetch_user_from_refresh_token
    end

    # jtiエラーの処理
    def catch_invalid_jti
      delete_session
      raise JWT::InvalidJtiError
    end

    # 認証エラー
    def unauthorized_user
      delete_session
      head(:unauthorized)
    end
end
