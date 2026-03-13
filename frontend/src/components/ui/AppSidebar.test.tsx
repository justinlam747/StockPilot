import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { AppProvider } from '@shopify/polaris';
import enTranslations from '@shopify/polaris/locales/en.json';
import AppSidebar from './AppSidebar';

const mockNavigate = vi.fn();

vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

function renderSidebar(props: { expanded?: boolean; initialRoute?: string } = {}) {
  const { expanded = true, initialRoute = '/' } = props;
  return render(
    <AppProvider i18n={enTranslations}>
      <MemoryRouter initialEntries={[initialRoute]}>
        <AppSidebar expanded={expanded} onToggle={vi.fn()} />
      </MemoryRouter>
    </AppProvider>,
  );
}

describe('AppSidebar', () => {
  beforeEach(() => {
    mockNavigate.mockClear();
  });

  it('renders all navigation items', () => {
    renderSidebar();

    expect(screen.getByLabelText('Dashboard')).toBeInTheDocument();
    expect(screen.getByLabelText('Inventory')).toBeInTheDocument();
    expect(screen.getByLabelText('Reports')).toBeInTheDocument();
    expect(screen.getByLabelText('Suppliers')).toBeInTheDocument();
    expect(screen.getByLabelText('Orders')).toBeInTheDocument();
    expect(screen.getByLabelText('Agents')).toBeInTheDocument();
    expect(screen.getByLabelText('Settings')).toBeInTheDocument();
  });

  it('clicking a nav item navigates', () => {
    renderSidebar();

    screen.getByLabelText('Inventory').click();
    expect(mockNavigate).toHaveBeenCalledWith('/inventory');
  });

  it('toggle button calls onToggle', () => {
    const onToggle = vi.fn();
    render(
      <AppProvider i18n={enTranslations}>
        <MemoryRouter>
          <AppSidebar expanded={true} onToggle={onToggle} />
        </MemoryRouter>
      </AppProvider>,
    );

    const toggleBtn = screen.getByLabelText('Collapse sidebar');
    toggleBtn.click();
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it('shows expanded class when expanded=true', () => {
    renderSidebar({ expanded: true });
    const nav = screen.getByLabelText('Main navigation');
    expect(nav).toHaveClass('app-sidebar--expanded');
  });

  it('does not show expanded class when expanded=false', () => {
    renderSidebar({ expanded: false });
    const nav = screen.getByLabelText('Main navigation');
    expect(nav).not.toHaveClass('app-sidebar--expanded');
  });

  it('shows aria-current on active item', () => {
    renderSidebar({ initialRoute: '/' });
    const dashboardBtn = screen.getByLabelText('Dashboard');
    expect(dashboardBtn).toHaveAttribute('aria-current', 'page');
  });

  it('does not show aria-current on inactive items', () => {
    renderSidebar({ initialRoute: '/' });
    const inventoryBtn = screen.getByLabelText('Inventory');
    expect(inventoryBtn).not.toHaveAttribute('aria-current');
  });
});
