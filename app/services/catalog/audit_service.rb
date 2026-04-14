# frozen_string_literal: true

module Catalog
  # Single source of truth for catalog quality issues.
  #
  # Contract:
  # - dashboard and issues views consume the same issue objects
  # - issue codes stay stable so filters and future exports do not drift
  # - ordering is deterministic so repeated syncs render the same list order
  class AuditService
    ISSUE_SEVERITY_ORDER = {
      'critical' => 0,
      'warning' => 1
    }.freeze

    Issue = Struct.new(
      :fingerprint,
      :severity,
      :code,
      :title,
      :detail,
      :product,
      :variant,
      :admin_url,
      keyword_init: true
    ) do
      def message
        detail
      end
    end

    def initialize(shop)
      @shop = shop
    end

    def issues
      @issues ||= build_issues.sort_by { |issue| sort_key(issue) }
    end

    def summary
      affected_product_ids = issues.map { |issue| issue.product.id }.uniq

      {
        total_products: products.count,
        total_variants: variants.count,
        issue_count: issues.count,
        affected_product_count: affected_product_ids.count,
        critical_issue_count: issues.count { |issue| issue.severity == 'critical' },
        warning_issue_count: issues.count { |issue| issue.severity == 'warning' }
      }
    end

    private

    def products
      @products ||= Product.where(shop_id: @shop.id).active.includes(:variants).to_a
    end

    def variants
      @variants ||= products.flat_map(&:variants)
    end

    def build_issues
      product_issues + duplicate_sku_issues + variant_issues
    end

    def product_issues
      products.flat_map do |product|
        issues = []
        issues << issue_for(product, nil, 'warning', 'missing_image', 'Missing product image',
                            'Add a primary product image to improve merchandising and conversion.') if product.image_url.blank?
        issues << issue_for(product, nil, 'warning', 'blank_vendor', 'Blank vendor',
                            'Set a vendor so the catalog stays filterable and easier to manage.') if product.vendor.blank?
        issues << issue_for(product, nil, 'warning', 'blank_product_type', 'Blank product type',
                            'Set a product type so reporting and merchandising remain clean.') if product.product_type.blank?
        issues << issue_for(product, nil, 'warning', 'title_too_short', 'Weak product title',
                            'Use a more descriptive title so the product is easier to scan and search.') if product.title.to_s.strip.length < 6
        issues
      end
    end

    def duplicate_sku_issues
      duplicate_groups = variants.group_by { |variant| normalized_sku(variant.sku) }
                                 .reject { |sku, group| sku.blank? || group.size < 2 }

      duplicate_groups.flat_map do |sku, group|
        group.map do |variant|
          issue_for(
            variant.product,
            variant,
            'critical',
            'duplicate_sku',
            'Duplicate SKU',
            "SKU #{sku} is used by #{group.size} variants in this store."
          )
        end
      end
    end

    def variant_issues
      variants.flat_map do |variant|
        issues = []
        issues << issue_for(variant.product, variant, 'warning', 'missing_sku', 'Missing SKU',
                            'Add a SKU so this variant can be identified consistently across ops and feeds.') if variant.sku.blank?
        issues << issue_for(variant.product, variant, 'critical', 'missing_price', 'Missing or zero price',
                            'Set a positive price for this variant before relying on the catalog for merchandising.') if variant.price.blank? || variant.price.to_f <= 0
        issues
      end
    end

    def issue_for(product, variant, severity, code, title, detail)
      Issue.new(
        fingerprint: [code, product.id, variant&.id].compact.join(':'),
        severity: severity,
        code: code,
        title: title,
        detail: detail,
        product: product,
        variant: variant,
        admin_url: admin_url_for(product)
      )
    end

    def normalized_sku(sku)
      sku.to_s.strip.upcase
    end

    def admin_url_for(product)
      "https://#{@shop.shop_domain}/admin/products/#{product.shopify_product_id}"
    end

    def sort_key(issue)
      [
        ISSUE_SEVERITY_ORDER.fetch(issue.severity, 99),
        issue.product.title.to_s.downcase,
        issue.variant&.sku.to_s.downcase,
        issue.code.to_s,
        issue.fingerprint.to_s
      ]
    end
  end
end
