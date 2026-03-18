# frozen_string_literal: true

class CreateWeeklyReports < ActiveRecord::Migration[7.2]
  def change
    create_table :weekly_reports do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.date    :week_start, null: false
      t.date    :week_end,   null: false
      t.jsonb   :payload,    null: false, default: {}
      t.timestamp :emailed_at

      t.timestamp :created_at, null: false, default: -> { 'NOW()' }
    end

    add_index :weekly_reports, %i[shop_id week_start], unique: true
  end
end
