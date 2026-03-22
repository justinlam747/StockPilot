# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserHardDeleteJob, type: :job do
  it 'hard-deletes users soft-deleted more than 30 days ago' do
    old = create(:user, deleted_at: 31.days.ago)
    recent = create(:user, deleted_at: 5.days.ago)
    active = create(:user)

    described_class.new.perform

    expect(User.find_by(id: old.id)).to be_nil
    expect(User.find_by(id: recent.id)).to be_present
    expect(User.find_by(id: active.id)).to be_present
  end
end
