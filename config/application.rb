require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # https://api.rubyonrails.org/v8.0/classes/Rails/Application/Configuration.html#method-i-load_defaults
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # データベースに保存する際のタイムゾーンをutcに設定することで、一貫した時間管理を行う。
    config.time_zone = ENV['TZ'] # 表示用のタイムゾーンを環境変数から取得
    config.active_record.default_timezone = :utc # データベースに保存する際のタイムゾーンをUTCに設定

    # デフォルトのロケールを日本語に設定
    # config/locales/ja.ymlが読み込まれるようにする。
    config.i18n.default_locale = :ja

    # Cookieを処理するmiddlewareを追加
    config.middleware.use ActionDispatch::Cookies

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
