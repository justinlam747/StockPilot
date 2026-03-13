/**
 * Component Playground — renders all pages with mock data.
 * Collapsible icon sidebar matching the main app design.
 */
import { useState } from "react";
import "@shopify/polaris/build/esm/styles.css";
import { AppProvider, Frame } from "@shopify/polaris";
import {
  Dashboard,
  Catalog,
  Analytics,
  UserMultiple,
  DocumentAdd,
  Bot,
  Settings as SettingsIcon,
  ChevronLeft,
  ChevronRight,
  Grid as GridIcon,
  Rocket,
} from "@carbon/icons-react";

import DashboardPage from "../../frontend/src/pages/DashboardPage";
import InventoryPage from "../../frontend/src/pages/InventoryPage";
import InventoryGridPage from "./InventoryGridPage";
import ReportsPage from "../../frontend/src/pages/ReportsPage";
import SuppliersPage from "../../frontend/src/pages/SuppliersPage";
import PurchaseOrdersPage from "../../frontend/src/pages/PurchaseOrdersPage";
import AgentsPage from "../../frontend/src/pages/AgentsPage";
import SettingsPage from "../../frontend/src/pages/SettingsPage";
import StockPilotHero from "./StockPilotHero";

const PAGES = [
  { label: "StockPilot Hero", icon: Rocket, component: StockPilotHero },
  { label: "Dashboard", icon: Dashboard, component: DashboardPage },
  { label: "Inventory (Grid)", icon: GridIcon, component: InventoryGridPage },
  { label: "Inventory (Table)", icon: Catalog, component: InventoryPage },
  { label: "Reports", icon: Analytics, component: ReportsPage },
  { label: "Suppliers", icon: UserMultiple, component: SuppliersPage },
  { label: "Purchase Orders", icon: DocumentAdd, component: PurchaseOrdersPage },
  { label: "Agents", icon: Bot, component: AgentsPage },
  { label: "Settings", icon: SettingsIcon, component: SettingsPage },
] as const;

export default function Playground() {
  const [activeIndex, setActiveIndex] = useState(0);
  const [expanded, setExpanded] = useState(false);
  const ActiveComponent = PAGES[activeIndex].component;

  return (
    <AppProvider i18n={{}}>
      <div className={`app-shell${expanded ? " app-shell--expanded" : ""}`}>
        {/* Collapsible sidebar */}
        <nav
          className={`app-sidebar${expanded ? " app-sidebar--expanded" : ""}`}
          aria-label="Playground navigation"
        >
          <div className="sidebar-top">
            {PAGES.map((page, i) => {
              const Icon = page.icon;
              const active = i === activeIndex;
              return (
                <button
                  key={page.label}
                  className={`sidebar-item${active ? " sidebar-item--active" : ""}`}
                  onClick={() => setActiveIndex(i)}
                  aria-label={page.label}
                  title={page.label}
                >
                  <span className="sidebar-item-icon">
                    <Icon size={20} />
                  </span>
                  <span className="sidebar-item-label">{page.label}</span>
                </button>
              );
            })}
          </div>
          <div className="sidebar-bottom">
            <button
              className="sidebar-item sidebar-toggle"
              onClick={() => setExpanded(!expanded)}
              aria-label={expanded ? "Collapse sidebar" : "Expand sidebar"}
            >
              <span className="sidebar-item-icon">
                {expanded ? <ChevronLeft size={20} /> : <ChevronRight size={20} />}
              </span>
              <span className="sidebar-item-label">Collapse</span>
            </button>
          </div>
        </nav>

        {/* Page content */}
        <main className="app-main">
          <Frame>
            <ActiveComponent />
          </Frame>
        </main>
      </div>
    </AppProvider>
  );
}
