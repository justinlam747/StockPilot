# frozen_string_literal: true

# Public vision/blog page — no auth required.
class VisionController < ApplicationController
  skip_before_action :require_login
  layout 'landing'
end
