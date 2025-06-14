class User < ApplicationRecord
  # gem bcrypt
  # 1. パスワードをハッシュ化して暗号化する
  # 2. password_digestをpasswordに設定する
  # 3. password_confirmation => パスワードの一致確認
  # 4. 一致のバリデーション追加
  # 5. authenticate()
  # 6. 最大文字数のバリデーション追加（72文字まで）
  # 7. User.create() => password_digestを必須入力, User.update() => 入力必須のバリデーションなし
  has_secure_password

  validates :name,
            presence: true, # 名前は必須
            length: { maximum: 50 } # 名前の最大文字数は50文字
  
  validates :email,
            presence: true, # メールアドレスは必須
            format: { with: URI::MailTo::EMAIL_REGEXP }, # メールアドレスの形式をチェック
            uniqueness: {
              case_sensitive: false, # 大文字小文字を区別しない
              conditions: -> { where(activated: true) } # アクティブなユーザーのみ一意性をチェック
            }
  
  validates :password,
            presence: true, # パスワードは必須
            length: { minimum: 8 }, # パスワードの最小文字数は8文字
            allow_nil: true # nilの場合はバリデーションをスキップ
end
