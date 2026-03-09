class AfterAuthenticateJob < ApplicationJob
  queue_as :default

  def perform(shop_domain:)
    raise NotImplementedError
  end
end
