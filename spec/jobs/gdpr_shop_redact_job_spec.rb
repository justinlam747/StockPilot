require "rails_helper"

RSpec.describe GdprShopRedactJob do
  let(:shop) { create(:shop) }

  before do
    ActsAsTenant.with_tenant(shop) do
      supplier = create(:supplier)
      product = create(:product)
      variant = create(:variant, product: product)
      create(:alert, variant: variant)
      create(:inventory_snapshot, variant: variant)
      po = create(:purchase_order, supplier: supplier)
      create(:purchase_order_line_item, purchase_order: po, variant: variant)
    end
  end

  it "deletes all shop data and the shop itself" do
    expect { described_class.new.perform(shop.id) }
      .to change(Shop, :count).by(-1)
      .and change(Product, :count).by(-1)
      .and change(Variant, :count).by(-1)
      .and change(Supplier, :count).by(-1)
      .and change(Alert, :count).by(-1)
      .and change(PurchaseOrder, :count).by(-1)
  end
end
