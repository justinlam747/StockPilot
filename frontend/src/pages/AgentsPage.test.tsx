import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { screen } from '@testing-library/react';
import { renderWithProviders } from '../test/test-utils';
import AgentsPage from './AgentsPage';

describe('AgentsPage', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders agent page', () => {
    renderWithProviders(<AgentsPage />);
    expect(screen.getByText('Agents')).toBeInTheDocument();
  });

  it('renders agent cards', () => {
    renderWithProviders(<AgentsPage />);
    // Agent names appear in multiple places (cards, feed, chat), so use getAllByText
    expect(screen.getAllByText('Inventory Monitor').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('PO Drafter').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Lead Scout').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Approval Gate').length).toBeGreaterThanOrEqual(1);
  });

  it('renders activity feed', () => {
    renderWithProviders(<AgentsPage />);
    expect(screen.getByText('Activity Feed')).toBeInTheDocument();
  });

  it('renders tool registry', () => {
    renderWithProviders(<AgentsPage />);
    expect(screen.getByText('Tool Registry')).toBeInTheDocument();
  });
});
