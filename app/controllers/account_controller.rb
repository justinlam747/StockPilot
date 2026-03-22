# frozen_string_literal: true

# User account management and logout.
class AccountController < ApplicationController
  skip_before_action :require_shop_connection

  def show
    @shops = current_user.shops.order(:created_at)
  end

  def destroy
    AuditLog.record(action: 'logout', metadata: { user_id: current_user&.id }, request: request)
    reset_session
    redirect_to root_path
  end

  # Development-only: auto-login as the first user
  def dev_login
    return head :not_found unless Rails.env.development?

    user = User.first
    return redirect_to root_path, alert: 'No users. Run: rails db:seed' unless user

    # Store Clerk user ID in session for dev — clerk_session_user_id falls back to this
    session[:dev_clerk_user_id] = user.clerk_user_id
    redirect_to '/dashboard'
  end
end
