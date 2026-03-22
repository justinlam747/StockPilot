# frozen_string_literal: true

# Permanently deletes users that were soft-deleted more than 30 days ago.
# Clears the active_shop_id reference before cascading shop destruction to avoid
# circular FK violations (users.active_shop_id → shops, shops.user_id → users).
class UserHardDeleteJob < ApplicationJob
  queue_as :default

  GRACE_PERIOD = 30.days

  def perform
    User.where.not(deleted_at: nil)
        .where(deleted_at: ...GRACE_PERIOD.ago)
        .find_each do |user|
      ApplicationRecord.transaction do
        user.update_columns(active_shop_id: nil) # rubocop:disable Rails/SkipsModelValidations
        user.shops.destroy_all
        user.destroy!
      end
      Rails.logger.info("[UserHardDelete] Permanently deleted user #{user.id}")
    end
  end
end
