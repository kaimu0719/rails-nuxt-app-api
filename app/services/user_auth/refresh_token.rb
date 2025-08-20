require 'jwt'

module UserAuth
  class RefreshToken
    include TokenCommons

    attr_reader :user_id, :payload, :token

    def initialize(user_id: nil, token: nil)
      if token.present?
        # decode
        @token = token

        # [{payload}, {header}]のようは配列が返ってくるため、.firstでindexが0の値を指定する
        @payload = JWT.decode(@token.to_s, decode_key, true, verify_claims).first

        # ペイロードの情報からユーザーIDを取得する
        @user_id = get_user_id_from(@payload)
      else
        # DBに保存するためのJWT IDを生成
        @user_id = encrypt_for(user_id)

        # 任意のユーザー情報をペイロードに設定
        @payload = claims

        # クライアントに返すトークンを生成
        @token = JWT.encode(@payload, secret_key, algorithm, header_fields)
        remember_jti(user_id)
      end
    end

    # 暗号化されたuserIDからユーザーを取得する
    def entity_for_user(id = nil)
      id ||= @user_id
      User.find(decrypt_for(id))
    end

    private

      # リフレッシュトークンの有効期限
      def token_lifetime
        UserAuth.refresh_token_lifetime
      end

      # 有効期限をUnixtimeで返す(必須)
      def token_expiration
         token_lifetime.from_now.to_i
      end

      # jwt_idの生成(必須)
      # SecureRandom.uuidで一意の値を返し、Digest::MD5.hexdigestメソッドでハッシュ化を行う
      def jwt_id
        Digest::MD5.hexdigest(SecureRandom.uuid)
      end

      # エンコード時のデフォルトクレーム
      def claims
        {
          user_claim => @user_id,
          jti: jwt_id,
          exp: token_expiration
        }
      end

      # @payloadのjtiを返す
      def payload_jti
        @payload.with_indifferent_access[:jti]
      end

      # jtiをUsersテーブルに保存する
      def remember_jti(user_id)
        User.find(user_id).remember(payload_jti)
      end

      ##  デコードメソッド

      # デコード時のjwt_idを検証する(エラーはJWT::DecodeErrorに委託する)
      def verify_jti?(jti, payload)
        # ペイロードからuser_idを取得
        user_id = get_user_id_from(payload)

        # デコードしたuser_idを用いて、Usersテーブルからユーザーを取得
        decode_user = entity_for_user(user_id)

        # ユーザーテーブルに保存されているjtiとデコードしたjtiが一致するかを検証
        decode_user.refresh_jti == jti
      rescue UserAuth.not_found_exception_class
        false
      end

      # デコード時のデフォルトオプション
      # Doc: https://github.com/jwt/ruby-jwt
      # default: https://www.rubydoc.info/github/jwt/ruby-jwt/master/JWT/DefaultOptions
      def verify_claims
        {
          verify_expiration: true,           # 有効期限の検証するか(必須)
          verify_jti: proc { |jti, payload|  # jtiとセッションIDの検証
            verify_jti?(jti, payload)
          },
          algorithm: algorithm               # decode時のアルゴリズム
        }
      end
  end
end
