class CreateAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :alerts do |t|
      t.references :shop,    null: false, foreign_key: { on_delete: :cascade }
      t.references :variant, null: false, foreign_key: { on_delete: :cascade }
      t.string  :alert_type, null: false
      t.string  :channel,    null: false
      t.string  :status,     null: false, default: "sent"
      t.timestamp :triggered_at, null: false, default: -> { "NOW()" }
      t.jsonb   :metadata,   default: {}

      t.timestamp :created_at, null: false, default: -> { "NOW()" }
    end

    add_index :alerts, [:shop_id, :variant_id, :triggered_at],
              name: "idx_alerts_variant_day"
  end
end
