import "@shopify/polaris/build/esm/styles.css";
import { AppProvider } from "@shopify/polaris";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import DashboardPage from "./pages/DashboardPage";
import InventoryPage from "./pages/InventoryPage";
import ReportsPage from "./pages/ReportsPage";
import SuppliersPage from "./pages/SuppliersPage";
import PurchaseOrdersPage from "./pages/PurchaseOrdersPage";
import SettingsPage from "./pages/SettingsPage";

export default function App() {
  return (
    <AppProvider i18n={{}}>
      <BrowserRouter>
        <ui-nav-menu>
          <a href="/" rel="home">Dashboard</a>
          <a href="/inventory">Inventory</a>
          <a href="/reports">Reports</a>
          <a href="/suppliers">Suppliers</a>
          <a href="/purchase-orders">Purchase Orders</a>
          <a href="/settings">Settings</a>
        </ui-nav-menu>
        <Routes>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/inventory" element={<InventoryPage />} />
          <Route path="/reports" element={<ReportsPage />} />
          <Route path="/suppliers" element={<SuppliersPage />} />
          <Route path="/purchase-orders" element={<PurchaseOrdersPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </BrowserRouter>
    </AppProvider>
  );
}
