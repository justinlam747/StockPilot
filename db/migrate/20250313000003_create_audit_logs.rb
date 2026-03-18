# frozen_string_literal: true

class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :shop, foreign_key: true
      t.string :action, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      t.jsonb :metadata, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, %i[shop_id created_at]
  end
end
