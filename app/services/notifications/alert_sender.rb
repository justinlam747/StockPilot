# frozen_string_literal: true

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
          channel: 'email',
          status: 'active',
          threshold: fv[:threshold],
          current_quantity: fv[:available],
          triggered_at: Time.current
        )
      end

      return unless @shop.alert_email.present?

      AlertMailer.low_stock(@shop, new_alerts, @shop.alert_email).deliver_later
    end
  end
end
