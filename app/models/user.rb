# frozen_string_literal: true

# A SaaS user authenticated via Clerk. Owns one or more Shopify stores.
class User < ApplicationRecord
  has_many :shops, dependent: :restrict_with_error
  belongs_to :active_shop, class_name: 'Shop', optional: true

  STORE_CATEGORIES = %w[apparel home electronics other].freeze

  validates :clerk_user_id, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :onboarding_step, inclusion: { in: 1..4 }
  validates :store_category, inclusion: { in: STORE_CATEGORIES }, allow_nil: true

  scope :active, -> { where(deleted_at: nil) }

  def onboarding_completed?
    onboarding_completed_at.present?
  end
end
