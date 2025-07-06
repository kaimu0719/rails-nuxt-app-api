class Api::V1::AuthTokenController < ApplicationController
  include UserSessionizeService

  # 404エラーが発生した場合にヘッダーのみを返す
  rescue_from UserAuth.not_found_exception_class, with: :not_found
  # refresh_tokenのInvalidJitErrorが発生した場合はカスタムエラーを返す
  rescue_from JWT::InvalidJtiError, with: :invalid_jti

  # userのログイン情報を確認する
  before_action :authenticate, only: [:create]
  # 処理前にsessionを削除する
  before_action :delete_session, only: [:create]
  # session_userを取得、存在しない場合は401を返す
  before_action :sessionize_user, only: [:refresh, :destroy]

  # ログイン
  def create
    # リフレッシュトークンからユーザーを取得
    # 取得できない場合は、authenticateメソッドで404が発生する
    @user = login_user

    # リフレッシュトークンなどをcookieにセットする
    set_refresh_token_to_cookie

    # ログイン完了時のレスポンス
    render json: login_response
  end

  # リフレッシュトークンを使用してアクセストークンを更新するためのアクション
  def refresh
    # UserSessionizeServiceモジュールのsession_userメソッドを使用して、
    # Cookieに保存されているリフレッシュトークンからユーザーを取得
    # 取得できない場合は、unauthorized 401 エラーが発生する
    @user = session_user

    # リフレッシュトークンなどをcookieにセットする
    set_refresh_token_to_cookie

    # ログイン完了時のレスポンス
    render json: login_response
  end

  # ログアウト
  def destroy
    # UserSessionizeServiceのdelete_sessionメソッドで、リフレッシュトークンのCookieを削除し、
    # Userモデルのforgetメソッドでユーザーのremember_jtiカラムをnilに更新する
    delete_session if session_user.forget

    # cookieのリフレッシュトークンキーがnilだった場合は ok 200を返して
    # 存在している場合は、server error 500 を返して、セッションが削除できなかったことを伝える
    cookies[session_key].nil? ?
      head(:ok) : response_500("Could not delete session")
  end

  private

    # params[:email]からアクティブなユーザーを返す
    def login_user
      # ユーザーが存在しない場合はnilを返す
      @_login_user ||= User.find_by_activated(auth_params[:email])
    end

    # ログインユーザーが居ない、もしくはpasswordが一致しない場合404を返す
    def authenticate
      # ログインユーザーがnilの場合と、パスワードが一致しない場合は、
      # 404 Not Foundエラーが発生し、ユーザーが見つからないことを示す
      unless login_user.present? &&
          # authenticateメソッドは、bcrypt gemによって提供されるメソッド
          login_user.authenticate(auth_params[:password])
        raise UserAuth.not_found_exception_class
      end
   end

    # refresh_tokenをcookieにセットする
    def set_refresh_token_to_cookie
      # UserSessionizeSercviceモジュールのsession_keyメソッドを使用して、セッションキーを取得し
      # cookiesにリフレッシュトークンをセットする
      cookies[session_key] = {
        value: refresh_token, # Userモデルのインスタンスから生成されたリフレッシュトークンをセット
        expires: refresh_token_expiration, # リフレッシュトークンの有効期限をセット
        secure: Rails.env.production?, # 本番環境ではsecure属性をtrueに設定
        http_only: true # JavaScriptからアクセスできないようにするため、httpOnly属性をtrueに設定
      }
    end

    # ログイン時のデフォルトレスポンス
    def login_response
      {
        # vuexのメモリに保存するためのログイン完了時に、アクセストークンをセットする
        token: access_token,

        # アクセストークンの有効期限をセット
        expires: access_token_expiration,

        # ユーザー情報をセット
        user: @user.response_json(sub: access_token_subject)
      }
    end

    # リフレッシュトークンのインスタンス生成
    def encode_refresh_token
      @_encode_refresh_token ||= @user.encode_refresh_token
    end

    # リフレッシュトークン
    def refresh_token
      encode_refresh_token.token
    end

    # リフレッシュトークンの有効期限
    def refresh_token_expiration
      Time.at(encode_refresh_token.payload[:exp])
    end

    # アクセストークンのインスタンス生成
    def encode_access_token
      @_encode_access_token ||= @user.encode_access_token
    end

    # アクセストークン
    def access_token
      encode_access_token.token
    end

    # アクセストークンの有効期限
    def access_token_expiration
      encode_access_token.payload[:exp]
    end

    # アクセストークンのsubjectクレーム
    def access_token_subject
      encode_access_token.payload[:sub]
    end

    # 404ヘッダーのみの返却を行う
    # Doc: https://gist.github.com/mlanett/a31c340b132ddefa9cca
    def not_found
      head(:not_found)
    end

    # decode jti != user.refresh_jti のエラー処理
    def invalid_jti
      msg = "Invalid jti for refresh token"
      render status: 401, json: { status: 401, error: msg }
    end

    def auth_params
      params.require(:auth).permit(:email, :password)
    end
end
