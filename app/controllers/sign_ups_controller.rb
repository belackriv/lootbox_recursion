class SignUpsController < InertiaController
  allow_unauthenticated_access

  def show
    render inertia: "Auth/SignUp", props: {
      errors: {}
    }
  end

  def create
    @user = User.new(sign_up_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path
    else
      redirect_to sign_up_path, inertia: { errors: @user.errors.messages }
    end
  end

  private
    def sign_up_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
