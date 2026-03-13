import { describe, it, expect } from 'vitest';
import { renderWithProviders, screen } from '../test/test-utils';
import LandingPage from './LandingPage';

describe('LandingPage', () => {
  it('renders hero section', () => {
    renderWithProviders(<LandingPage />);
    // Hero subtitle is a single text node
    expect(screen.getByText(/Autonomous agents that monitor stock/i)).toBeInTheDocument();
    expect(screen.getAllByText(/Agentic Inventory Management/i).length).toBeGreaterThanOrEqual(1);
  });

  it('renders features section', () => {
    renderWithProviders(<LandingPage />);
    expect(screen.getByText(/Four agents\./i)).toBeInTheDocument();
    // Agent feature card titles
    expect(screen.getAllByText('Inventory Monitor agent').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('PO Drafter agent').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Lead Scout agent').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Approval Gate').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Customer DNA profiles').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('Autonomous weekly reports').length).toBeGreaterThanOrEqual(1);
  });

  it('has CTA buttons', () => {
    renderWithProviders(<LandingPage />);
    const ctaButtons = screen.getAllByText(/Deploy/i);
    expect(ctaButtons.length).toBeGreaterThanOrEqual(2);
  });

  it('renders open source section', () => {
    renderWithProviders(<LandingPage />);
    expect(screen.getByText('Proudly open source.')).toBeInTheDocument();
    expect(screen.getByText('View on GitHub')).toBeInTheDocument();
  });
});
