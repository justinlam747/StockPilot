module Notifications
  class AlertSender
    def initialize(shop)
      @shop = shop
    end

    def send_low_stock_alerts(flagged_variants)
      return if flagged_variants.empty?

      today_range = Time.current.beginning_of_day..Time.current.end_of_day
      already_alerted_ids = Alert
        .where(shop_id: @shop.id, triggered_at: today_range)
        .pluck(:variant_id)
        .to_set

      new_alerts = flagged_variants.reject { |fv| already_alerted_ids.include?(fv[:variant].id) }
      return if new_alerts.empty?

      new_alerts.each do |fv|
        Alert.create!(
          shop: @shop,
          variant: fv[:variant],
          alert_type: fv[:status].to_s,
          status: "active",
          threshold: fv[:threshold],
          current_quantity: fv[:available],
          triggered_at: Time.current
        )
      end

      if @shop.alert_email.present?
        AlertMailer.low_stock(@shop, new_alerts, @shop.alert_email).deliver_later
      end

      fire_outgoing_webhooks(new_alerts)
    end

    private

    def fire_outgoing_webhooks(new_alerts)
      endpoints = WebhookEndpoint.where(shop_id: @shop.id, event_type: "low_stock", is_active: true)
      return if endpoints.empty?

      payload = {
        event: "low_stock",
        shop: @shop.shop_domain,
        variants: new_alerts.map do |fv|
          {
            id: fv[:variant].id,
            sku: fv[:variant].sku,
            title: fv[:variant].title,
            available: fv[:available],
            status: fv[:status].to_s,
            threshold: fv[:threshold]
          }
        end
      }

      endpoints.each do |endpoint|
        WebhookDeliveryJob.perform_later(endpoint.id, payload.to_json)
      end
    end
  end
end
