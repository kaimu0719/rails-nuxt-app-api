ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # アクティブなユーザーを返す
    def active_user
      User.create!(name: "Kaimu", email: "kaimu@a.com", password: "password", activated: true)
    end

    # api path
    def api(path = "/")
      "/api/v1#{path}"
    end

    # 引数のparamsでログインを行う
    def login(params)
      post api("/auth_token"), xhr: true, params: params
    end

    # ログアウトapi
    def logout
      delete api("/auth_token"), xhr: true
    end

    # レスポンスJSONをハッシュで返す
    def res_body
      # @response は ActionDispatch::TestResponse クラスである
      @response.parsed_body
    end
  end
end
