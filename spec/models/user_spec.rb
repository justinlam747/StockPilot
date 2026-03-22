# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:shops).dependent(:destroy) }
    it { is_expected.to belong_to(:active_shop).class_name('Shop').optional }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:clerk_user_id) }
    it { is_expected.to validate_uniqueness_of(:clerk_user_id) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value('test@example.com').for(:email) }
    it { is_expected.to_not allow_value('not-an-email').for(:email) }
    it { is_expected.to validate_inclusion_of(:onboarding_step).in_range(1..4) }
  end

  describe 'scopes' do
    it 'active excludes soft-deleted users' do
      active = create(:user)
      create(:user, deleted_at: Time.current)
      expect(User.active).to eq([active])
    end
  end

  describe '#onboarding_completed?' do
    it 'returns false when onboarding_completed_at is nil' do
      user = build(:user, onboarding_completed_at: nil)
      expect(user.onboarding_completed?).to be false
    end

    it 'returns true when onboarding_completed_at is set' do
      user = build(:user, onboarding_completed_at: Time.current)
      expect(user.onboarding_completed?).to be true
    end
  end
end
