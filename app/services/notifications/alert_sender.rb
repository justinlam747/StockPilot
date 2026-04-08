# frozen_string_literal: true

module Notifications
  # Creates alert records and sends notification emails for low-stock variants.
  class AlertSender
    def initialize(shop)
      @shop = shop
    end

    def create_alerts_and_notify(flagged_variants)
      return if flagged_variants.empty?

      new_alerts = remove_already_alerted_today(flagged_variants)
      return if new_alerts.empty?

      new_alerts.each { |fv| create_alert(fv) }
      send_email(new_alerts)
    end

    private

    def remove_already_alerted_today(flagged_variants)
      today_range = Time.current.beginning_of_day..Time.current.end_of_day
      already_alerted_ids = Alert.where(shop_id: @shop.id, triggered_at: today_range)
                                 .pluck(:variant_id).to_set
      flagged_variants.reject { |fv| already_alerted_ids.include?(fv[:variant].id) }
    end

    def create_alert(flagged_variant)
      Alert.create!(
        shop: @shop, variant: flagged_variant[:variant],
        alert_type: flagged_variant[:status].to_s,
        channel: 'email', status: 'active',
        threshold: flagged_variant[:threshold],
        current_quantity: flagged_variant[:available],
        triggered_at: Time.current
      )
    end

    def send_email(new_alerts)
      return unless @shop.alert_email.present?

      AlertMailer.low_stock(@shop, new_alerts, @shop.alert_email).deliver_later
    end
  end
end
