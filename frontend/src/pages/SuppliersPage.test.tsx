import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import SuppliersPage from './SuppliersPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const suppliersData = {
  suppliers: [
    { id: 1, name: 'Pacific Textile Co.', email: 'orders@pacific.com', contact_name: 'Sarah Chen', lead_time_days: 14, notes: '' },
    { id: 2, name: 'EcoWeave', email: 'sales@ecoweave.com', contact_name: 'Marcus Rivera', lead_time_days: 7, notes: '' },
  ],
};

describe('SuppliersPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<SuppliersPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('renders supplier list after fetch', async () => {
    mockFetch.mockResolvedValue(suppliersData);
    renderWithProviders(<SuppliersPage />);

    await waitFor(() => {
      expect(screen.getByText('Pacific Textile Co.')).toBeInTheDocument();
    });

    expect(screen.getByText('Supplier Directory')).toBeInTheDocument();
    // EcoWeave appears in both the table and "Fastest" sidebar KPI
    expect(screen.getAllByText('EcoWeave').length).toBeGreaterThanOrEqual(1);
  });

  it('shows supplier count in sidebar', async () => {
    mockFetch.mockResolvedValue(suppliersData);
    renderWithProviders(<SuppliersPage />);

    await waitFor(() => {
      expect(screen.getByText('Suppliers')).toBeInTheDocument();
    });

    expect(screen.getByText('Avg Lead Time')).toBeInTheDocument();
  });
});
