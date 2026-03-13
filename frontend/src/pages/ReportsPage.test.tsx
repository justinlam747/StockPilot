import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import ReportsPage from './ReportsPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const reportsData = {
  reports: [
    { id: 1, week_start: '2026-03-03', created_at: '2026-03-04T08:00:00Z', emailed_at: '2026-03-04T09:00:00Z' },
    { id: 2, week_start: '2026-03-10', created_at: '2026-03-11T08:00:00Z', emailed_at: null },
  ],
};

describe('ReportsPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<ReportsPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('renders report list after fetch', async () => {
    mockFetch.mockResolvedValue(reportsData);
    renderWithProviders(<ReportsPage />);

    await waitFor(() => {
      expect(screen.getByText('Weekly Reports')).toBeInTheDocument();
    });

    expect(screen.getByText('Total Reports')).toBeInTheDocument();
    expect(screen.getByText('Generate Report')).toBeInTheDocument();
  });

  it('shows report counts in sidebar', async () => {
    mockFetch.mockResolvedValue(reportsData);
    renderWithProviders(<ReportsPage />);

    await waitFor(() => {
      expect(screen.getByText('Emailed')).toBeInTheDocument();
    });

    // "Pending" appears in both table status and sidebar KPI
    expect(screen.getAllByText('Pending').length).toBeGreaterThanOrEqual(1);
  });
});
