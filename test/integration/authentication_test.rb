require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def setup
    @user = active_user

    @params = { auth: { email: @user.email, password: "password" } }

    @access_lifetime = UserAuth.access_token_lifetime

    @session_key = UserAuth.session_key.to_s
  end

  test "GET #index プロジェクト一覧にアクセスできる" do
    # ログインができて、アクセストークンを取得する
    post api_v1_auth_token_index_url, xhr: true, params: @params

    get api_v1_projects_url, xhr: true, headers: { :Authorization => "Bearer #{response.parsed_body["token"]}" }
    assert_response 200
    assert response.body.present?
  end

  test "GET #index アクセストークンの有効期限が過ぎている場合にプロジェクト一覧にアクセスできない" do
    post api_v1_auth_token_index_url, xhr: true, params: @params

    # 時刻を現在時刻からアクセストークンの有効期限まで伸ばしてブロック内のテストを実行する
    travel_to (@access_lifetime.from_now) do
      # Cookieにセッションキーが入っていることを確認
      assert cookies[@session_key].present?

      get api_v1_projects_url, xhr: true, headers: { :Authorization => "Bearer #{response.parsed_body["token"]}" }

      assert_response 401
      assert_not response.body.present?

      # アクセストークンが有効ではない状態で保護されているAPIにアクセスした際に、
      # Cookieのセッションキーが削除されていることを確認する
      assert cookies[@session_key].blank?
    end
  end

  test "GET #index 無効なアクセストークンの場合はプロジェクト一覧にアクセスできない" do
    post api_v1_auth_token_index_url, xhr: true, params: @params

    # 不正なtokenが投げられた場合
    invalid_token = "a." + response.parsed_body["token"]
    get api_v1_projects_url, xhr: true, headers: { :Authorization => "Bearer #{invalid_token}" }

    assert_response 401
    assert_not response.body.present?
  end
end
