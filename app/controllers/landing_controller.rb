# frozen_string_literal: true

class LandingController < ApplicationController
  skip_before_action :require_login
  layout 'landing'

  def index; end
end
