# frozen_string_literal: true

# Sends purchase order drafts to suppliers via email.
class PurchaseOrderMailer < ApplicationMailer
  def send_po(purchase_order)
    @po = purchase_order
    @supplier = purchase_order.supplier
    mail(
      to: @supplier.email,
      subject: "Purchase Order ##{@po.id} from #{@po.shop.shop_domain}"
    ) do |format|
      format.text { render plain: @po.draft_body }
    end
  end
end
