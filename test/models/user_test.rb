require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "invalid without name" do
    user = User.new(name: "", email: "a@example.com", password: "password123")

    # 名前が空の場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["名前を入力してください"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "invalid when name exceeds maximum length" do
    long_name = "a" * 51 # 51文字の名前を作成
    user = User.new(
      name: long_name,
      email: "long@example.com",
      password: "password123"
    )

    # 名前が最大文字数を超える場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["名前は50文字以内で入力してください"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "valid when name length is exactly 50 characters" do
    exact_name = "a" * 50 # 50文字の名前を作成
    user = User.new(
      name: exact_name,
      email: "exact@example.com",
      password: "password123"
    )

    # 名前が50文字の場合、ユーザーは有効であることを確認
    assert user.valid?

    # エラーメッセージがないことを確認
    assert_empty user.errors.full_messages
  end

  test "invalid without email" do
    user = User.new(name: "Test User", email: "", password: "password123")

    # メールアドレスが空の場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["メールアドレスを入力してください"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "invalid with improperly formatted email" do
    user = User.new(name: "Test User", email: "invalid_email", password: "password123")

    # 不正な形式のメールアドレスの場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["メールアドレスは不正な値です"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "valid with properly formmatted email" do
    user = User.new(name: "Test User", email: "a@a.a", password: "password123")

    # 正しい形式のメールアドレスの場合、ユーザーは有効であることを確認
    assert user.valid?

    # エラーメッセージがないことを確認
    assert_empty user.errors.full_messages
  end

  test "invalid with duplicate email for activated users" do
    # 既存のアクティブなユーザーを作成
    existing_user = User.create!(
      name: "Existing User",
      email: "existing@example.com",
      password: "password123",
      activated: true
    )

    # 同じメールアドレスを持つ新しいユーザーを作成
    user = User.new(
      name: "New User",
      email: existing_user.email,
      password: "newpassword123"
    )

    # アクティブなユーザーのメールアドレスが重複する場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["メールアドレスはすでに存在します"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "valid with unique email for activated users" do
    # 既存のアクティブなユーザーを作成
    User.create!(
      name: "Existing User",
      email: "existing@example.com",
      password: "password123",
      activated: true
    )

    # 異なるメールアドレスを持つ新しいユーザーを作成
    user = User.new(
      name: "New User",
      email: "new@example.com",
      password: "newpassword123"
    )

    # 異なるメールアドレスの場合、ユーザーは有効であることを確認
    assert user.valid?

    # エラーメッセージがないことを確認
    assert_empty user.errors.full_messages
  end

  test "invalid without password" do
    user = User.new(name: "Test User", email: "test@example.com", password: "")

    # パスワードが空の場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["パスワードを入力してください"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "invalid with short password" do
    user = User.new(name: "Test User", email: "test@example.com", password: "short")

    # パスワードが短い場合、ユーザーは無効であることを確認
    assert_not user.valid?

    # 表示されるエラーメッセージが正しいことを確認
    error_messages = ["パスワードは8文字以上で入力してください"]
    assert_equal user.errors.full_messages, error_messages
  end

  test "valid with password of minimum length" do
    user = User.new(name: "Test User", email: "test@example.com", password: "password")

    # パスワードが最小文字数を満たす場合、ユーザーは有効であることを確認
    assert user.valid?

    # エラーメッセージがないことを確認
    assert_empty user.errors.full_messages
  end

  test "password remains unchanged and update is valid when no password params are given" do
    user = User.create!(name: "Test User", email: "test@example.com", password: "password123")
    original_digest = user.password_digest

    # パスワードを更新せずにユーザー情報を更新
    assert_no_changes("user.reload.password_digest") do
      assert user.update!(name: "Renamed User", password: "")
    end
  end
end
