import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import DashboardPage from './DashboardPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const dashboardData = {
  total_skus: 150,
  low_stock_count: 12,
  out_of_stock_count: 3,
  synced_at: '2026-03-10T12:00:00Z',
  low_stock_items: [
    { id: 1, sku: 'BLK-TEE-M', title: 'Black Tee Medium', available: 4, threshold: 10 },
    { id: 2, sku: 'WHT-HOOD-L', title: 'White Hoodie Large', available: 0, threshold: 5 },
  ],
};

describe('DashboardPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<DashboardPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('shows dashboard data after fetch completes', async () => {
    mockFetch.mockResolvedValue(dashboardData);
    renderWithProviders(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Dashboard')).toBeInTheDocument();
    });

    expect(screen.getByText('150')).toBeInTheDocument();
  });

  it('shows metric cards (low stock, out of stock)', async () => {
    mockFetch.mockResolvedValue(dashboardData);
    renderWithProviders(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('12')).toBeInTheDocument();
    });

    expect(screen.getByText('3')).toBeInTheDocument();
    // "Low Stock" and "Out of Stock" appear as both metric labels and table status text
    expect(screen.getAllByText('Low Stock').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Out of Stock').length).toBeGreaterThanOrEqual(1);
  });

  it('sync button triggers POST to /inventory/sync', async () => {
    mockFetch.mockResolvedValue(dashboardData);
    renderWithProviders(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Sync Now')).toBeInTheDocument();
    });

    mockFetch.mockResolvedValue({});
    screen.getByText('Sync Now').click();

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith('/inventory/sync', { method: 'POST' });
    });
  });
});
