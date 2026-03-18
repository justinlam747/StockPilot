# frozen_string_literal: true

class AlertMailer < ApplicationMailer
  def low_stock(shop, flagged_variants, to)
    @shop = shop
    @flagged_variants = flagged_variants
    mail(
      to: to,
      subject: "[#{shop.shop_domain}] #{flagged_variants.size} low-stock items detected"
    )
  end
end
