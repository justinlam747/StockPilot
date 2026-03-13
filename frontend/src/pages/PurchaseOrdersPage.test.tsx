import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import PurchaseOrdersPage from './PurchaseOrdersPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const purchaseOrdersData = {
  purchase_orders: [
    {
      id: 101,
      status: 'sent',
      order_date: '2026-03-05',
      expected_delivery: '2026-03-19',
      draft_body: null,
      supplier: { id: 1, name: 'Pacific Textile Co.' },
      line_items: [{ id: 1, sku: 'BLK-TEE-M', quantity_ordered: 100, unit_price: 8.5 }],
    },
    {
      id: 102,
      status: 'draft',
      order_date: '2026-03-10',
      expected_delivery: null,
      draft_body: 'Draft email body',
      supplier: { id: 2, name: 'EcoWeave' },
      line_items: [{ id: 2, sku: 'WHT-HOOD-L', quantity_ordered: 50, unit_price: 15.0 }],
    },
  ],
};

const suppliersData = {
  suppliers: [
    { id: 1, name: 'Pacific Textile Co.' },
    { id: 2, name: 'EcoWeave' },
  ],
};

describe('PurchaseOrdersPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<PurchaseOrdersPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('renders PO list after fetch', async () => {
    mockFetch
      .mockResolvedValueOnce(purchaseOrdersData)
      .mockResolvedValueOnce(suppliersData);

    renderWithProviders(<PurchaseOrdersPage />);

    await waitFor(() => {
      expect(screen.getByText('Order History')).toBeInTheDocument();
    });

    expect(screen.getByText('Purchase Orders')).toBeInTheDocument();
    expect(screen.getByText('Generate Draft')).toBeInTheDocument();
  });

  it('shows PO counts in sidebar', async () => {
    mockFetch
      .mockResolvedValueOnce(purchaseOrdersData)
      .mockResolvedValueOnce(suppliersData);

    renderWithProviders(<PurchaseOrdersPage />);

    await waitFor(() => {
      expect(screen.getByText('Total Orders')).toBeInTheDocument();
    });

    expect(screen.getByText('Sent')).toBeInTheDocument();
    expect(screen.getByText('Drafts')).toBeInTheDocument();
  });
});
