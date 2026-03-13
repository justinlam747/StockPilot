import { describe, it, expect, vi, beforeEach } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import SettingsPage from './SettingsPage';

const mockFetch = vi.fn();

vi.mock('../hooks/useAuthenticatedFetch', () => ({
  useAuthenticatedFetch: () => mockFetch,
}));

const settingsData = {
  alert_email: 'test@example.com',
  low_stock_threshold: 10,
  timezone: 'America/Toronto',
  weekly_report_day: 'monday',
};

const webhooksData = {
  webhook_endpoints: [
    { id: 1, url: 'https://hooks.slack.com/test', event_type: 'low_stock', is_active: true },
  ],
};

describe('SettingsPage', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };
    mockFetch.mockReset();
  });

  it('shows loading spinner initially', () => {
    mockFetch.mockReturnValue(new Promise(() => {}));
    renderWithProviders(<SettingsPage />);
    expect(document.querySelector('.Polaris-Spinner')).toBeInTheDocument();
  });

  it('loads and displays settings values', async () => {
    mockFetch
      .mockResolvedValueOnce(settingsData)
      .mockResolvedValueOnce(webhooksData);

    renderWithProviders(<SettingsPage />);

    await waitFor(() => {
      expect(screen.getByText('Alert & Report Settings')).toBeInTheDocument();
    });

    expect(screen.getByText('test@example.com')).toBeInTheDocument();
    expect(screen.getByText('10 units')).toBeInTheDocument();
  });

  it('save button calls PATCH /settings', async () => {
    mockFetch
      .mockResolvedValueOnce(settingsData)
      .mockResolvedValueOnce(webhooksData);

    renderWithProviders(<SettingsPage />);

    await waitFor(() => {
      expect(screen.getByText('Save Settings')).toBeInTheDocument();
    });

    mockFetch.mockResolvedValue({});
    screen.getByText('Save Settings').click();

    await waitFor(() => {
      expect(mockFetch).toHaveBeenCalledWith(
        '/settings',
        expect.objectContaining({ method: 'PATCH' }),
      );
    });
  });
});
