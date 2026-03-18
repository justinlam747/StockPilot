# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PurchaseOrderMailer, type: :mailer do
  let(:shop) { create(:shop, shop_domain: 'gadgets.myshopify.com') }
  let(:supplier) { create(:supplier, shop: shop, name: 'ACME Supply Co', email: 'orders@acme.example.com') }

  let(:purchase_order) do
    create(:purchase_order,
           shop: shop,
           supplier: supplier,
           status: 'draft',
           draft_body: "Please ship 100 units of Widget-A and 50 units of Widget-B.\nThank you.")
  end

  describe '#send_po' do
    let(:mail) { described_class.send_po(purchase_order) }

    it 'sends to the supplier email' do
      expect(mail.to).to eq(['orders@acme.example.com'])
    end

    it 'renders the subject with PO id and shop domain' do
      expect(mail.subject).to eq(
        "Purchase Order ##{purchase_order.id} from gadgets.myshopify.com"
      )
    end

    it 'includes the draft_body in the text body' do
      # The mailer renders format.text with the draft_body
      text_part = mail.body.encoded
      expect(text_part).to include('Please ship 100 units of Widget-A')
      expect(text_part).to include('50 units of Widget-B')
    end

    it 'renders as a text/plain email' do
      expect(mail.content_type).to include('text/plain')
    end
  end
end
