# frozen_string_literal: true

module Webhooks
  # Handles Clerk webhook events for user lifecycle (create, update, delete).
  class ClerkController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_clerk_webhook

    def receive
      event_type = params[:type]
      data = params[:data]

      case event_type
      when 'user.created'  then handle_user_created(data)
      when 'user.updated'  then handle_user_updated(data)
      when 'user.deleted'  then handle_user_deleted(data)
      else Rails.logger.info("[Clerk Webhook] Unhandled event: #{event_type}")
      end

      head :ok
    end

    private

    def verify_clerk_webhook
      signing_secret = ENV.fetch('CLERK_WEBHOOK_SIGNING_SECRET', '')
      return head :unauthorized if signing_secret.blank?

      payload = request.body.read
      request.body.rewind
      headers = {
        'svix-id' => request.headers['svix-id'],
        'svix-timestamp' => request.headers['svix-timestamp'],
        'svix-signature' => request.headers['svix-signature']
      }

      begin
        wh = Svix::Webhook.new(signing_secret)
        wh.verify(payload, headers)
      rescue Svix::WebhookVerificationError
        AuditLog.record(action: 'clerk_webhook_verification_failed', request: request)
        head :unauthorized
      end
    end

    def handle_user_created(data)
      email = data.dig(:email_addresses, 0, :email_address)
      User.find_or_create_by!(clerk_user_id: data[:id]) do |user|
        user.email = email
        user.name = [data[:first_name], data[:last_name]].compact.join(' ')
      end
    rescue ActiveRecord::RecordNotUnique => e
      retries ||= 0
      retries += 1
      retry if retries < 3
      raise e
    end

    def handle_user_updated(data)
      user = User.find_by(clerk_user_id: data[:id])
      return unless user

      email = data.dig(:email_addresses, 0, :email_address)
      user.update!(
        email: email,
        name: [data[:first_name], data[:last_name]].compact.join(' ')
      )
    end

    def handle_user_deleted(data)
      user = User.find_by(clerk_user_id: data[:id])
      return unless user

      user.update!(deleted_at: Time.current)
      AuditLog.record(action: 'user_soft_deleted', metadata: { clerk_user_id: data[:id] })
    end
  end
end
