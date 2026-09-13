import { NavLink, Route, Routes } from "react-router-dom";
import { ToastProvider } from "./toast";
import DashboardPage from "./pages/DashboardPage";
import EventsPage from "./pages/EventsPage";
import RulesPage from "./pages/RulesPage";
import ZonesPage from "./pages/ZonesPage";
import SensorsPage from "./pages/SensorsPage";
import AuditPage from "./pages/AuditPage";
import ReportsPage from "./pages/ReportsPage";

const NAV = [
  { to: "/", label: "风险总览", end: true },
  { to: "/events", label: "风险事件" },
  { to: "/zones", label: "库区与微气候" },
  { to: "/rules", label: "规则版本" },
  { to: "/devices", label: "传感器设备" },
  { to: "/audit", label: "审计日志" },
  { to: "/reports", label: "报表导出" }
];

export default function App() {
  return (
    <ToastProvider>
      <div className="app-shell">
        <aside className="sidebar">
          <h1>纸质档案库房</h1>
          <div className="subtitle">微气候风险监测系统</div>
          <nav>
            {NAV.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                end={n.end}
                className={({ isActive }) => (isActive ? "active" : "")}
              >
                {n.label}
              </NavLink>
            ))}
          </nav>
        </aside>
        <main>
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/events" element={<EventsPage />} />
            <Route path="/zones" element={<ZonesPage />} />
            <Route path="/rules" element={<RulesPage />} />
            <Route path="/devices" element={<SensorsPage />} />
            <Route path="/audit" element={<AuditPage />} />
            <Route path="/reports" element={<ReportsPage />} />
          </Routes>
        </main>
      </div>
    </ToastProvider>
  );
}
