import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderWithProviders, screen } from '../../test/test-utils';
import Toast from './Toast';

describe('Toast', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders message text', () => {
    renderWithProviders(
      <Toast message="Item saved" onDismiss={vi.fn()} />,
    );
    expect(screen.getByText('Item saved')).toBeInTheDocument();
  });

  it('renders with success variant by default', () => {
    renderWithProviders(
      <Toast message="Success" onDismiss={vi.fn()} />,
    );
    const toast = screen.getByRole('status');
    expect(toast).toHaveClass('toast--success');
  });

  it('renders with error variant', () => {
    renderWithProviders(
      <Toast message="Failed" variant="error" onDismiss={vi.fn()} />,
    );
    const toast = screen.getByRole('alert');
    expect(toast).toHaveClass('toast--error');
  });

  it('calls onDismiss after duration', () => {
    const onDismiss = vi.fn();
    renderWithProviders(
      <Toast message="Auto dismiss" onDismiss={onDismiss} duration={2000} />,
    );

    expect(onDismiss).not.toHaveBeenCalled();
    vi.advanceTimersByTime(2000);
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it('calls onDismiss after default duration (3500ms)', () => {
    const onDismiss = vi.fn();
    renderWithProviders(
      <Toast message="Default timer" onDismiss={onDismiss} />,
    );

    vi.advanceTimersByTime(3499);
    expect(onDismiss).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1);
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });

  it('dismiss button calls onDismiss on click', async () => {
    const onDismiss = vi.fn();
    renderWithProviders(
      <Toast message="Click dismiss" onDismiss={onDismiss} />,
    );

    const button = screen.getByLabelText('Dismiss');
    button.click();
    expect(onDismiss).toHaveBeenCalledTimes(1);
  });
});
