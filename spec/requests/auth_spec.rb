# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Auth', type: :request do
  describe 'DELETE /logout' do
    let(:user) { create(:user, :with_shop) }

    before { sign_in_as(user) }

    it 'resets session and redirects to root' do
      delete '/logout'
      expect(response).to redirect_to('/')
    end

    it 'creates an audit log entry' do
      expect do
        delete '/logout'
      end.to change(AuditLog.where(action: 'logout'), :count).by(1)
    end
  end
end
