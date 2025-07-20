require "test_helper"
# テスト成功要件
# cookies[]の操作にはapplication.rbにCookieを処理するmeddlewareを追加
# config.middleware.use ActionDispatch::Cookies
class Api::V1::AuthTokenControllerTest < ActionDispatch::IntegrationTest
  def setup
    # テスト用のメール認証が完了しているユーザーを取得
    # fixtures/users.ymlのデータを使用
    @user = active_user

    # ログインする際に使用するパラメータを設定
    @params = { auth: { email: @user.email, password: "password" } }

    # アクセストークンの有効期限を取得
    @access_lifetime = UserAuth.access_token_lifetime

    # リフレッシュトークンの有効期限を取得
    @refresh_lifetime = UserAuth.refresh_token_lifetime

    # セッションキーを設定
    @session_key = UserAuth.session_key.to_s
  end

  # 無効なリクエストで返ってくるレスポンスチェック
  def response_check_of_invalid_request(status, error_msg = nil)
    assert_response status
    @user.reload
    assert_nil @user.refresh_jti
    assert_not response.body.present? if error_msg.nil?
    assert_equal error_msg, response.parsed_body["error"] if !error_msg.nil?
  end

  test "POST #create ログインフォームからメールアドレスとパスワードでログインができる" do
    # メールアドレスとパスワードを、XHRリクエストで送信してステータスコードが200であることを確認する
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200

    # 
    access_lifetime_to_i = @access_lifetime.from_now.to_i
    refresh_lifetime_to_i = @refresh_lifetime.from_now.to_i

    # jtiは保存されているか
    @user.reload
    assert_not_nil @user.refresh_jti

    # レスポンスユーザーは正しいか
    assert_equal @user.id, response.parsed_body["user"]["id"]

    # レスポンス有効期限は想定通りか(1誤差許容)
    assert_in_delta access_lifetime_to_i,
                    response.parsed_body["expires"],
                    1

    ## access_token
    access_token = User.decode_access_token(response.parsed_body["token"])

    # ユーザーはログイン本人と一致しているか
    assert_equal @user, access_token.entity_for_user

    # 有効期限はレスポンスと一致しているか
    token_exp = access_token.payload["exp"]
    assert_equal response.parsed_body["expires"], token_exp

    ## cookie
    # cookieのオプションを取得する場合は下記を使用
    # @request.cookie_jar.instance_variable_get(:@set_cookies)[<key>]
    cookie = @request.cookie_jar.
             instance_variable_get(:@set_cookies)[@session_key]

    # expiresは想定通りか(1秒許容)
    assert_in_delta Time.at(refresh_lifetime_to_i),
                    cookie[:expires],
                    1.seconds

    # secureは一致しているか
    assert_equal Rails.env.production?, cookie[:secure]

    # http_onlyはtrueか
    assert cookie[:http_only]

    ## refresh_token
    refresh_token = User.decode_refresh_token(cookies[@session_key])
    @user.reload

    # ログイン本人と一致しているか
    assert_equal @user, refresh_token.entity_for_user

    # jtiは一致しているか
    assert_equal @user.refresh_jti, refresh_token.payload["jti"]

    # token有効期限とcookie有効期限は一致しているか
    assert_equal refresh_lifetime_to_i, refresh_token.payload["exp"]
  end

  # 無効なログイン
  test "POST #create ログインフォームでパスワードが間違っている場合はログインできない" do
    # 不正なユーザーの場合
    pass = "password"
    invalid_params = { auth: { email: @user.email, password: pass + "a" } }

    post api_v1_auth_token_index_url, xhr: true, params: invalid_params
    response_check_of_invalid_request 404

    # アクティブユーザーでない場合
    inactive_user = User.create(name: "a", email: "b@b.b", password: pass)
    invalid_params = { auth: { email: inactive_user.email, password: pass } }
    assert_not inactive_user.activated
    post api_v1_auth_token_index_url, xhr: true, params: invalid_params
    response_check_of_invalid_request 404

    # Ajax通信ではない場合
    post api_v1_auth_token_index_url, xhr: false, params: @params
    response_check_of_invalid_request 403, "Forbidden"
  end

  # 有効なリフレッシュ
  test "POST #refresh ログインした後に有効なリフレッシュトークンをユーザーにセットし、cookieに保存されている" do
    # 有効なログイン
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200
    @user.reload
    old_access_token = response.parsed_body["token"]
    old_refresh_token = cookies[@session_key]
    old_user_jti = @user.refresh_jti

    # nilでないか
    assert_not_nil old_access_token
    assert_not_nil old_refresh_token
    assert_not_nil old_user_jti

    travel 10.second

    # refreshアクションにアクセス
    post refresh_api_v1_auth_token_index_url, xhr: true
    assert_response 200
    @user.reload
    new_access_token = response.parsed_body["token"]
    new_refresh_token = cookies[@session_key]
    new_user_jti = @user.refresh_jti

    # nilでないか
    assert_not_nil new_access_token
    assert_not_nil new_refresh_token
    assert_not_nil new_user_jti

    # tokenとjtiが新しく発行されているか
    assert_not_equal old_access_token, new_access_token
    assert_not_equal old_refresh_token, new_refresh_token
    assert_not_equal old_user_jti, new_user_jti

    # user.refresh_jtiは最新のjtiと一致しているか
    payload = User.decode_refresh_token(new_refresh_token).payload
    assert_equal payload["jti"], new_user_jti
  end

  # 無効なリフレッシュ
  test "POST #refresh 無効なリフレッシュトークンの挙動と、未ログイン時にリフレッシュトークンが取得できない" do
    # refresh_tokenが存在しない場合はアクセスできないか
    post refresh_api_v1_auth_token_index_url, xhr: true
    response_check_of_invalid_request 401

    ## ユーザーが2回のログインを行なった場合
    # 1つ目のブラウザでログイン
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200
    old_refresh_token = cookies[@session_key]

    # 2つ目のブラウザでログイン
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200
    new_refresh_token = cookies[@session_key]

    # cookieに古いrefresh_tokenをセット
    cookies[@session_key] = old_refresh_token
    assert_not cookies[@session_key].blank?

    # 1つ目のブラウザ(古いrefresh_token)でアクセスするとエラーを吐いているか
    post refresh_api_v1_auth_token_index_url, xhr: true
    assert_response 401

    # cookieは削除されているか
    assert cookies[@session_key].blank?

    # jtiエラーはカスタムメッセージを吐いているか
    assert_equal "Invalid jti for refresh token", response.parsed_body["error"]

    # 有効期限後はアクセスできないか
    travel_to (@refresh_lifetime.from_now) do
      post refresh_api_v1_auth_token_index_url, xhr: true
      assert_response 401
      assert_not response.body.present?
    end
  end

  # ログアウト
  test "DELETE #destroy ログアウトできる" do
    # まずばログインしておく
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200
    @user.reload
    assert_not_nil @user.refresh_jti
    assert_not_nil @request.cookie_jar[@session_key]

    # 有効なログアウト
    assert_not cookies[@session_key].blank?
    delete api_v1_auth_token_index_url, xhr: true
    assert_response 200

    # cookieは削除されているか
    assert cookies[@session_key].blank?

    # userのjtiは削除できているか
    @user.reload
    assert_nil @user.refresh_jti

    # sessionがない状態でログアウトしたらエラーは返ってくるか
    cookies[@session_key] = nil
    delete api_v1_auth_token_index_url, xhr: true
    response_check_of_invalid_request 401

    # 有効なログイン
    post api_v1_auth_token_index_url, xhr: true, params: @params
    assert_response 200
    assert_not cookies[@session_key].blank?

    # session有効期限後にログアウトしたらエラーは返ってくるか
    travel_to (@refresh_lifetime.from_now) do
      delete api_v1_auth_token_index_url, xhr: true
      assert_response 401
      # cookieは削除されているか
      assert cookies[@session_key].blank?
    end
  end
end
