import { useLocation, useNavigate } from "react-router-dom";
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
} from "@carbon/icons-react";

interface NavItem {
  path: string;
  icon: typeof Dashboard;
  title: string;
}

const NAV_ITEMS: NavItem[] = [
  { path: "/", icon: Dashboard, title: "Dashboard" },
  { path: "/inventory", icon: Catalog, title: "Inventory" },
  { path: "/reports", icon: Analytics, title: "Reports" },
  { path: "/suppliers", icon: UserMultiple, title: "Suppliers" },
  { path: "/purchase-orders", icon: DocumentAdd, title: "Orders" },
  { path: "/agents", icon: Bot, title: "Agents" },
];

const BOTTOM_ITEMS: NavItem[] = [
  { path: "/settings", icon: SettingsIcon, title: "Settings" },
];

interface AppSidebarProps {
  expanded: boolean;
  onToggle: () => void;
}

export default function AppSidebar({ expanded, onToggle }: AppSidebarProps) {
  const location = useLocation();
  const navigate = useNavigate();

  const isActive = (path: string) =>
    path === "/" ? location.pathname === "/" : location.pathname.startsWith(path);

  const renderItem = (item: NavItem) => {
    const active = isActive(item.path);
    const Icon = item.icon;
    return (
      <button
        key={item.path}
        className={`sidebar-item${active ? " sidebar-item--active" : ""}`}
        onClick={() => navigate(item.path)}
        aria-label={item.title}
        aria-current={active ? "page" : undefined}
      >
        <span className="sidebar-item-icon">
          <Icon size={20} />
        </span>
        <span className="sidebar-item-label">{item.title}</span>
      </button>
    );
  };

  return (
    <nav
      className={`app-sidebar${expanded ? " app-sidebar--expanded" : ""}`}
      aria-label="Main navigation"
    >
      <div className="sidebar-top">
        {NAV_ITEMS.map(renderItem)}
      </div>
      <div className="sidebar-bottom">
        {BOTTOM_ITEMS.map(renderItem)}
        <button
          className="sidebar-item sidebar-toggle"
          onClick={onToggle}
          aria-label={expanded ? "Collapse sidebar" : "Expand sidebar"}
        >
          <span className="sidebar-item-icon">
            {expanded ? <ChevronLeft size={20} /> : <ChevronRight size={20} />}
          </span>
          <span className="sidebar-item-label">Collapse</span>
        </button>
      </div>
    </nav>
  );
}
