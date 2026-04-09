# frozen_string_literal: true

# Public landing page for unauthenticated visitors.
class LandingController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :scope_queries_to_current_shop
  layout 'landing'

  def index; end
end
