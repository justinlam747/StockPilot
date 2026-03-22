# frozen_string_literal: true

# Handles shop switching for multi-shop users.
class ShopsController < ApplicationController
  def switch
    shop = current_user.shops.active.find(params[:id])
    current_user.update!(active_shop_id: shop.id)
    redirect_back fallback_location: '/dashboard', notice: "Switched to #{shop.shop_domain}"
  end
end
