import "@shopify/polaris/build/esm/styles.css";
import "./styles/globals.css";
import "./styles/landing.css";
import { useState } from "react";
import { AppProvider } from "@shopify/polaris";
import { BrowserRouter, Routes, Route, useLocation } from "react-router-dom";

import AppSidebar from "./components/ui/AppSidebar";
import DashboardPage from "./pages/DashboardPage";
import InventoryPage from "./pages/InventoryPage";
import ReportsPage from "./pages/ReportsPage";
import SuppliersPage from "./pages/SuppliersPage";
import PurchaseOrdersPage from "./pages/PurchaseOrdersPage";
import SettingsPage from "./pages/SettingsPage";
import AgentsPage from "./pages/AgentsPage";
import LandingPage from "./pages/LandingPage";
import StockPilotLanding from "./pages/StockPilotLanding";

function AppRoutes() {
  const [sidebarExpanded, setSidebarExpanded] = useState(false);
  const location = useLocation();
  const isLanding = location.pathname === "/landing";
  const isStockPilot = location.pathname === "/stockpilot";

  if (isLanding) {
    return <LandingPage />;
  }

  if (isStockPilot) {
    return <StockPilotLanding />;
  }

  return (
    <div className={`app-shell${sidebarExpanded ? " app-shell--expanded" : ""}`}>
      <AppSidebar expanded={sidebarExpanded} onToggle={() => setSidebarExpanded(!sidebarExpanded)} />
      <main className="app-main">
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/inventory" element={<InventoryPage />} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="/suppliers" element={<SuppliersPage />} />
          <Route path="/purchase-orders" element={<PurchaseOrdersPage />} />
          <Route path="/agents" element={<AgentsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <AppProvider i18n={{}}>
      <BrowserRouter>
        <Routes>
          <Route path="/landing" element={<LandingPage />} />
          <Route path="/stockpilot" element={<StockPilotLanding />} />
          <Route path="/*" element={<AppRoutes />} />
        </Routes>
      </BrowserRouter>
    </AppProvider>
  );
}
