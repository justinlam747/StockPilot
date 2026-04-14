# frozen_string_literal: true

# Renders a lean dashboard focused on catalog health.
class DashboardController < ApplicationController
  def index
    unless current_shop
      @show_connect_banner = true
      return
    end

    audit = Catalog::AuditService.new(current_shop)
    load_catalog_summary(audit)
    @recent_issues = audit.issues.first(8)
  end

  def sync
    require_shop!
    return if performed?

    InventorySyncJob.perform_later(current_shop.id)
    redirect_to dashboard_path, notice: 'Catalog sync queued.'
  end

  private

  def load_catalog_summary(audit)
    # Keep the dashboard counts aligned with the issues page by deriving both
    # from the same audit run contract. Future edits should preserve that
    # single source of truth so summary cards never drift from the list view.
    summary = audit.summary
    @total_products = summary[:total_products]
    @total_variants = summary[:total_variants]
    @issue_count = summary[:issue_count]
    @affected_product_count = summary[:affected_product_count]
    @critical_issue_count = summary[:critical_issue_count]
    @warning_issue_count = summary[:warning_issue_count]
    healthy_product_count = (@total_products - @affected_product_count).clamp(0, @total_products)
    @catalog_coverage = @total_products.positive? ? (healthy_product_count.to_f / @total_products * 100).round : 100
  end
end
