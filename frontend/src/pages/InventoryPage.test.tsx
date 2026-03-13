import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import InventoryPage from './InventoryPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const productsData = {
  products: [
    { id: 1, title: 'Black T-Shirt', status: 'active', variants: [{ id: 10, sku: 'BLK-TEE-M', title: 'Medium' }] },
    { id: 2, title: 'White Hoodie', status: 'draft', variants: [{ id: 20, sku: 'WHT-HOOD-L', title: 'Large' }] },
  ],
  meta: { current_page: 1, total_pages: 1, total_count: 2, per_page: 25 },
};

describe('InventoryPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<InventoryPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('renders product cards after fetch', async () => {
    mockFetch.mockResolvedValue(productsData);
    renderWithProviders(<InventoryPage />);

    await waitFor(() => {
      expect(screen.getByText('Black T-Shirt')).toBeInTheDocument();
    });

    expect(screen.getByText('White Hoodie')).toBeInTheDocument();
    expect(screen.getByText('BLK-TEE-M')).toBeInTheDocument();
  });

  it('shows product count in header', async () => {
    mockFetch.mockResolvedValue(productsData);
    renderWithProviders(<InventoryPage />);

    await waitFor(() => {
      expect(screen.getByText('2 products')).toBeInTheDocument();
    });
  });
});
