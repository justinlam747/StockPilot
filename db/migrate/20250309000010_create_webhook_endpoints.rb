class CreateWebhookEndpoints < ActiveRecord::Migration[7.2]
  def change
    create_table :webhook_endpoints do |t|
      t.references :shop, null: false, foreign_key: { on_delete: :cascade }
      t.string  :url,        null: false
      t.string  :event_type, null: false
      t.boolean :is_active,  null: false, default: true
      t.timestamp :last_fired_at
      t.integer :last_status_code

      t.timestamps
    end
  end
end
