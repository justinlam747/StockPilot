# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  around_perform do |job, block|
    Rails.logger.tagged(self.class.name, job.job_id) do
      block.call
    end
  end
end
