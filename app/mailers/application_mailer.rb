# frozen_string_literal: true

# Base mailer with default sender configuration.
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAIL_FROM', 'noreply@example.com')
  layout 'mailer'
end
