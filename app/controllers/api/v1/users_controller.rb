class Api::V1::UsersController < ApplicationController
  def index
    render json: current_user.as_json(only: [:id, :name, :email, :created_at])
  end
end
