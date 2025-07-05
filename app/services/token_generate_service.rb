# Userモデルにトークン生成のメソッドを追加するためのモジュール
# app/models/user.rbにincludeして使用する

module TokenGenerateService
  # include時の初期化処理実行場所(include先のオブジェクト)
  def self.included(base)
    # include時にクラスメソッドを追加する。
    base.extend ClassMethods
  end

  ## クラスメソッド
  # このクラスメソッドは、Userモデルのクラスメソッドとして定義される
  # JWTをデコードすることによって、user_idを取得し、Userエンティティを返すメソッドなどがある。
  # またJWTのペイロード（有効期限、発行者、受信者などの情報）を含むアクセストークンやリフレッシュトークンのインスタンスを生成するメソッドもある。
  module ClassMethods

    # アクセストークンのインスタンス生成(オプション => sub: encrypt user id)
    # アクセストークンからuserを取得する際（entity_for_user）に使用
    #
    # アクセストークンのインスタンスには
    #   @options = {sub: encrypt user id}
    #   @payload = {exp: 有効期限, sub:, iss:, aud:},
    #   @token = "JWTトークン文字列"
    #   @user_id= エンコードされたユーザーID
    # が含まれる。
    def decode_access_token(token, options = {})
      UserAuth::AccessToken.new(token: token, options: options)
    end

    # アクセストークンをデコードして、ユーザーエンティティを返す。
    def from_access_token(token, options = {})
      # UserAuth::AccessTokenクラスのインスタンスを生成して、entity_for_userメソッドでユーザーエンティティを取得する。
      decode_access_token(token, options).entity_for_user
    end

    # リフレッシュトークンのインスタンス生成
    def decode_refresh_token(token)
      UserAuth::RefreshToken.new(token: token)
    end

    # リフレッシュトークンのuserを返す
    def from_refresh_token(token)
      decode_refresh_token(token).entity_for_user
    end

  end

  ## インスタンスメソッド
  # Userモデルのインスタンス作成時に使用するメソッド
  # インスタンス作成時に生成されるインスタンス変数のidを使用してトークンを生成する

  # アクセストークンのインスタンス生成
  def encode_access_token(payload = {})
    UserAuth::AccessToken.new(user_id: id, payload: payload)
  end

  # アクセストークンを返す(期限変更 => lifetime: 10.minute)
  def to_access_token(payload = {})
    encode_access_token(payload).token
  end

  # リフレッシュトークンのインスタンス生成
  # UserAuth::RefreshToken クラスのインスタンスを生成する
  def encode_refresh_token
    UserAuth::RefreshToken.new(user_id: id)
  end

  # リフレッシュトークンを返す
  def to_refresh_token
    encode_refresh_token.token
  end

end
