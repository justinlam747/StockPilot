# frozen_string_literal: true

# Represents a Clerk-authenticated user who owns one or more shops.
class User < ApplicationRecord
  has_many :shops, dependent: :destroy

  validates :clerk_user_id, presence: true, uniqueness: true
  validates :email, presence: true
end
