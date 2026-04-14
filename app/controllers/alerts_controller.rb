# frozen_string_literal: true

# Displays computed catalog audit issues.
class AlertsController < ApplicationController
  before_action :require_shop!

  def index
    # The audit service owns issue generation; this controller only shapes the
    # current view by applying lightweight filters to the in-memory result set.
    issues = Catalog::AuditService.new(current_shop).issues
    issues = apply_severity_filter(issues)
    issues = apply_search_filter(issues)
    @issues = Kaminari.paginate_array(issues).page(params[:page]).per(25)
    @search_query = params[:q].to_s.strip
    @current_severity = params[:severity].presence
  end

  private

  def apply_severity_filter(issues)
    case params[:severity]
    when 'critical', 'warning' then issues.select { |issue| issue.severity == params[:severity] }
    else issues
    end
  end

  def apply_search_filter(issues)
    return issues if params[:q].blank?

    query = params[:q].downcase
    issues.select do |issue|
      issue.product.title.to_s.downcase.include?(query) ||
        issue.variant&.sku.to_s.downcase.include?(query) ||
        issue.code.to_s.downcase.include?(query)
    end
  end
end
