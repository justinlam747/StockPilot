# frozen_string_literal: true

class AddMissingColumnsToAlertsAndPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :alerts, :threshold, :integer
    add_column :alerts, :current_quantity, :integer
    add_column :alerts, :dismissed, :boolean, default: false, null: false

    add_column :purchase_orders, :order_date, :date
    add_column :purchase_orders, :expected_delivery, :date
    add_column :purchase_orders, :po_notes, :text

    add_index :alerts, %i[shop_id dismissed], name: 'index_alerts_on_shop_id_and_dismissed'
    add_index :purchase_orders, %i[shop_id status], name: 'index_purchase_orders_on_shop_id_and_status'
    add_index :suppliers, %i[shop_id name], name: 'index_suppliers_on_shop_id_and_name'
  end
end
