# frozen_string_literal: true

# Renders the merchant dashboard with inventory stats.
class DashboardController < ApplicationController
  def index
    unless current_shop
      @show_connect_banner = true
      return
    end

    load_dashboard_stats
    load_trends
    @recent_alerts = Alert.includes(variant: :product).order(created_at: :desc).limit(10)
  end

  def toggle_demo
    if session[:demo_mode]
      session.delete(:demo_mode)
      session.delete(:demo_shop_id)
      redirect_to '/dashboard', notice: 'Demo mode off'
    else
      demo_shop = Shop.find_by(shop_domain: 'demo.myshopify.com')
      unless demo_shop
        redirect_to '/dashboard', alert: 'Demo data not seeded. Run: rails demo:seed'
        return
      end
      session[:demo_mode] = true
      session[:demo_shop_id] = demo_shop.id
      redirect_to '/dashboard', notice: 'Demo mode on'
    end
  end

  private

  def load_dashboard_stats
    stats = shop_cache.inventory_stats
    @total_products = stats[:total_products]
    @low_stock = stats[:low_stock]
    @out_of_stock = stats[:out_of_stock]
    @pending_pos = stats[:pending_pos]
    @total_suppliers = Supplier.where(shop_id: current_shop.id).count
    @total_alerts = Alert.where(shop_id: current_shop.id).count
    @total_variants = Variant.where(shop_id: current_shop.id).count
    @healthy_products = [@total_products - @low_stock - @out_of_stock, 0].max
    @health_pct = @total_products.positive? ? ((@healthy_products.to_f / @total_products) * 100).round : 0
    @sent_pos = PurchaseOrder.where(shop_id: current_shop.id, status: 'sent').count
    @alerts_today = Alert.where(shop_id: current_shop.id)
                        .where('created_at >= ?', Time.current.beginning_of_day).count
    @avg_variants_per_product = @total_products.positive? ? (@total_variants.to_f / @total_products).round(1) : 0
  end

  def load_trends
    @trends = compute_trends
  end

  def compute_trends
    snapshots = InventorySnapshot.where(shop_id: current_shop.id)
                                 .where('created_at < ?', 24.hours.ago)
    return default_trends unless snapshots.exists?

    prev = previous_counts(snapshots)
    {
      total_products: trend_direction(@total_products, prev[:total]),
      low_stock: trend_direction(@low_stock, prev[:low]),
      out_of_stock: trend_direction(@out_of_stock, prev[:out]),
      pending_pos: :flat
    }
  end

  def previous_counts(snapshots)
    prev_total = Product.where(shop_id: current_shop.id)
                        .where('created_at < ?', 24.hours.ago).count
    {
      total: prev_total.zero? ? @total_products : prev_total,
      low: snapshots.where('available > 0 AND available <= 10').count,
      out: snapshots.where('available <= 0').count
    }
  end

  def default_trends
    { total_products: :flat, low_stock: :flat, out_of_stock: :flat, pending_pos: :flat }
  end

  def trend_direction(current, previous)
    return :flat if current == previous

    current > previous ? :up : :down
  end

end
