# ドキュメント: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#config

# ワーカープロセス（fork）数の設定
# - Dyno内でOSプロセスを複数立ち上げ、CPUコアを並列活用
# - メモリ消費が大きいのでDynoサイズと相談して調整
workers Integer(ENV['WEB_CONCURRENCY'] || 2)

# スレッドプール数の設定
# - 1workerが並列に扱うリクエスト数（I/Oまちの隙間を活用）
# - min はアイドル時のスレッド保持数、maxが最大同時実行数
max_threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS") { 5 })
min_threads_count = Integer(ENV.fetch("RAILS_MIN_THREADS") { max_threads_count })
threads min_threads_count, max_threads_count

# preload_appをtrueに設定することで、アプリケーションの起動時間を短縮し、メモリ使用量を削減する。
preload_app!

# Rails生成の`config.ru`を使用する場合は、以下の行を有効にする。
rackup      DefaultRackup if defined?(DefaultRackup)

# HerokuではRouterがポートを指定するので、Pumaはそのポートを使用する。
port(ENV['PORT'] || 3000, "::")

# 実行環境
# - Heroku本番では`RACK_ENV=production`が自動で入る
environment ENV['RACK_ENV'] || 'development'