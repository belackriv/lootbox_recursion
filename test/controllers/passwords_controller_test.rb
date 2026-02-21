require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.take || User.create!(email_address: "passwords_controller_test@example.com", password: "password")
  end

  # ---------------------------------------------------------------------------
  # GET /passwords/new
  # ---------------------------------------------------------------------------

  test "new renders the ForgotPassword component" do
    get new_password_path

    assert_response :success
    assert_inertia_component "Auth/ForgotPassword"
    assert_inertia_props "currentUser" => nil, "errors" => {}
  end

  # ---------------------------------------------------------------------------
  # POST /passwords
  # ---------------------------------------------------------------------------

  test "create enqueues a password reset email and redirects" do
    post passwords_path, params: { email_address: @user.email_address }

    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path
  end

  test "create redirects to login with a notice after submitting a known email" do
    post passwords_path, params: { email_address: @user.email_address }
    follow_redirect!

    assert_inertia_flash "notice" => "Password reset instructions sent (if user with that email address exists)."
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "no-such-user@example.com" }

    assert_enqueued_emails 0
    assert_redirected_to new_session_path
  end

  test "create for an unknown user still shows the generic notice" do
    post passwords_path, params: { email_address: "no-such-user@example.com" }
    follow_redirect!

    assert_inertia_flash "notice" => "Password reset instructions sent (if user with that email address exists)."
  end

  # ---------------------------------------------------------------------------
  # GET /passwords/:token/edit
  # ---------------------------------------------------------------------------

  test "edit renders the ResetPassword component with the token prop" do
    token = @user.password_reset_token
    get edit_password_path(token)

    assert_response :success
    assert_inertia_component "Auth/ResetPassword"
    assert_inertia_props "token" => token, "currentUser" => nil
  end

  test "edit with an invalid token redirects to the forgot-password page" do
    get edit_password_path("this-token-is-not-valid")

    assert_redirected_to new_password_path
  end

  test "edit with an invalid token lands on the ForgotPassword component after redirect" do
    get edit_password_path("this-token-is-not-valid")
    follow_redirect!

    assert_inertia_component "Auth/ForgotPassword"
  end

  # ---------------------------------------------------------------------------
  # PUT /passwords/:token
  # ---------------------------------------------------------------------------

  test "update changes the password digest and redirects to login" do
    token = @user.password_reset_token
    assert_changes -> { @user.reload.password_digest } do
      put password_path(token),
          params: { password: "newpassword1", password_confirmation: "newpassword1" }
    end

    assert_redirected_to new_session_path
  end

  test "update shows a success notice after following the redirect" do
    token = @user.password_reset_token
    put password_path(token),
        params: { password: "newpassword1", password_confirmation: "newpassword1" }
    follow_redirect!

    assert_inertia_flash "notice" => "Password has been reset."
  end

  test "update with non-matching passwords does not change the digest" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token),
          params: { password: "aaa", password_confirmation: "bbb" }
    end
  end

  test "update with non-matching passwords redirects back to the edit page" do
    token = @user.password_reset_token
    put password_path(token), params: { password: "aaa", password_confirmation: "bbb" }

    assert_redirected_to edit_password_path(token)
  end

  test "update with non-matching passwords renders the ResetPassword component after redirect" do
    token = @user.password_reset_token
    put password_path(token), params: { password: "aaa", password_confirmation: "bbb" }
    follow_redirect!

    assert_inertia_component "Auth/ResetPassword"
  end
end
