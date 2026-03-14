class AuthController < ApplicationController
  skip_before_action :require_login

  def callback
    auth = request.env["omniauth.auth"]
    reset_session

    shop = Shop.find_or_initialize_by(shop_domain: auth.uid)
    shop.access_token = auth.credentials.token
    shop.installed_at ||= Time.current
    shop.save!

    session[:shop_id] = shop.id
    AuditLog.record(action: "login", shop: shop, request: request)
    redirect_to "/dashboard"
  end

  def failure
    AuditLog.record(action: "login_failed", request: request,
                    metadata: { reason: params[:message] })
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  def destroy
    AuditLog.record(action: "logout", shop: current_shop, request: request)
    reset_session
    redirect_to root_path
  end
end
