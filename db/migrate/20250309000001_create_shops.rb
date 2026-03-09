class CreateShops < ActiveRecord::Migration[7.2]
  def change
    create_table :shops do |t|
      t.string  :shop_domain,  null: false
      t.string  :access_token, null: false
      t.string  :plan,         default: "free"
      t.timestamp :installed_at, null: false, default: -> { "NOW()" }
      t.timestamp :uninstalled_at
      t.timestamp :synced_at
      t.jsonb   :settings,     null: false, default: {}

      t.timestamps
    end

    add_index :shops, :shop_domain, unique: true
  end
end
