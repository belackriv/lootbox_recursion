class SignUpsController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.new
  end

  def create
    @user = User.new(sign_up_params)
    if @user.save
      start_new_session_for(@user)
      redirect_to root_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def sign_up_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
