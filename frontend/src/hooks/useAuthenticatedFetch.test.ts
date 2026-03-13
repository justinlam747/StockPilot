import { renderHook } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { useAuthenticatedFetch } from './useAuthenticatedFetch';

describe('useAuthenticatedFetch', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).shopify = {
      idToken: vi.fn().mockResolvedValue('test-token'),
    };

    vi.spyOn(globalThis, 'fetch').mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({ data: 'test' }),
    } as unknown as Response);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('returns a function', () => {
    const { result } = renderHook(() => useAuthenticatedFetch());
    expect(typeof result.current).toBe('function');
  });

  it('calls fetch with correct base URL and auth header', async () => {
    const { result } = renderHook(() => useAuthenticatedFetch());

    await result.current('/shop');

    expect(globalThis.fetch).toHaveBeenCalledWith(
      '/api/v1/shop',
      expect.objectContaining({
        headers: expect.objectContaining({
          'Content-Type': 'application/json',
          Authorization: 'Bearer test-token',
        }),
      }),
    );
  });

  it('throws on non-ok response', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue({
      ok: false,
      status: 401,
    } as Response);

    const { result } = renderHook(() => useAuthenticatedFetch());

    await expect(result.current('/shop')).rejects.toThrow('API error: 401');
  });

  it('passes additional options through to fetch', async () => {
    const { result } = renderHook(() => useAuthenticatedFetch());

    await result.current('/settings', { method: 'PATCH', body: '{}' });

    expect(globalThis.fetch).toHaveBeenCalledWith(
      '/api/v1/settings',
      expect.objectContaining({
        method: 'PATCH',
        body: '{}',
      }),
    );
  });
});
