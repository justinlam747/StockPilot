# frozen_string_literal: true

module Agents
  # Builds a plain-text supplier reorder email draft from a purchase order.
  # Deterministic by default; uses SummaryClient for AI-assisted phrasing
  # when an AI provider is configured.
  class SupplierEmailDraft
    Draft = Struct.new(:subject, :body, :to, :from, keyword_init: true) do
      def to_h
        { subject: subject, body: body, to: to, from: from }
      end
    end

    class << self
      def call(purchase_order, summary_client: nil)
        new(purchase_order, summary_client: summary_client).call
      end
    end

    def initialize(purchase_order, summary_client: nil)
      @purchase_order = purchase_order
      @shop = purchase_order.shop
      @supplier = purchase_order.supplier
      @summary_client = summary_client
    end

    def call
      Draft.new(
        subject: subject_line,
        body: body_text,
        to: supplier.email,
        from: shop.alert_email
      )
    end

    private

    attr_reader :purchase_order, :shop, :supplier

    def subject_line
      "Purchase order ##{purchase_order.id} from #{shop.shop_domain}"
    end

    def body_text
      [
        greeting,
        '',
        opening_line,
        '',
        line_items_block,
        '',
        delivery_line,
        '',
        closing
      ].compact.join("\n")
    end

    def greeting
      name = supplier.contact_name.presence || supplier.name
      "Hi #{name},"
    end

    def opening_line
      total_units = purchase_order.line_items.sum(:qty_ordered)
      sku_count = purchase_order.line_items.size
      "We'd like to place a reorder for #{sku_count} SKU(s) totaling #{total_units} unit(s)."
    end

    def line_items_block
      purchase_order.line_items.map do |item|
        title = item.title.presence || item.variant&.title || item.sku
        "- #{item.sku || 'SKU'}: #{title} -- qty #{item.qty_ordered}"
      end.join("\n")
    end

    def delivery_line
      return "Order date: #{purchase_order.order_date.strftime('%b %d, %Y')}." if purchase_order.expected_delivery.blank?

      "Order date: #{purchase_order.order_date.strftime('%b %d, %Y')}. " \
        "Requested delivery by #{purchase_order.expected_delivery.strftime('%b %d, %Y')}."
    end

    def closing
      "Please confirm receipt and expected ship date.\n\nThanks,\n#{shop.shop_domain}"
    end
  end
end
