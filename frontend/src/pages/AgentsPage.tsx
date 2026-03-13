import { useState, useEffect, useRef } from "react";
import {
  Bot,
  Activity,
  Email,
  Search,
  Scan,
  SendAlt,
  Renew,
  Chat,
  Connect,
  Lightning,
  Pause,
  Play,
  CheckmarkOutline,
  WarningAlt,
  Catalog,
  Flow,
} from "@carbon/icons-react";
import { PageHeader, CountBadge } from "../components/ui";

/* ─── Types ─── */

interface ToolDef {
  id: string;
  label: string;
  icon: typeof Bot;
  color: string;
}

interface Agent {
  id: string;
  name: string;
  role: string;
  icon: typeof Bot;
  status: "running" | "idle" | "waiting";
  currentTask: string;
}

interface ToolCall {
  id: number;
  agentId: string;
  agentName: string;
  toolId: string;
  toolLabel: string;
  message: string;
  timestamp: Date;
  status: "running" | "done" | "waiting";
}

interface ChatMessage {
  id: number;
  from: string;
  to: string;
  message: string;
  timestamp: Date;
}

/* ─── Static Data ─── */

const TOOLS: ToolDef[] = [
  { id: "check_inventory", label: "Check Inventory", icon: Scan, color: "#6D7175" },
  { id: "analyze_trends", label: "Analyze Trends", icon: Activity, color: "#6D7175" },
  { id: "draft_email", label: "Draft Email", icon: Email, color: "#6D7175" },
  { id: "search_suppliers", label: "Search Suppliers", icon: Search, color: "#6D7175" },
  { id: "send_notification", label: "Send Notification", icon: SendAlt, color: "#6D7175" },
  { id: "await_approval", label: "Await Approval", icon: Pause, color: "#6D7175" },
  { id: "sync_data", label: "Sync Data", icon: Renew, color: "#6D7175" },
  { id: "validate", label: "Validate", icon: CheckmarkOutline, color: "#6D7175" },
];

const AGENTS: Agent[] = [
  { id: "monitor", name: "Inventory Monitor", role: "Scans stock levels every cycle, flags low-stock and out-of-stock SKUs", icon: Scan, status: "running", currentTask: "Scanning 142 SKUs..." },
  { id: "drafter", name: "PO Drafter", role: "Drafts purchase order emails from low-stock data, stages for approval", icon: Email, status: "idle", currentTask: "Waiting for trigger..." },
  { id: "scout", name: "Lead Scout", role: "Finds new manufacturers and alternative suppliers, compares lead times", icon: Search, status: "running", currentTask: "Searching textile suppliers..." },
  { id: "approver", name: "Approval Gate", role: "Holds drafted POs until a human reviews and approves them", icon: CheckmarkOutline, status: "waiting", currentTask: "1 PO pending approval" },
];

const INITIAL_FEED: ToolCall[] = [
  { id: 1, agentId: "monitor", agentName: "Inventory Monitor", toolId: "check_inventory", toolLabel: "Check Inventory", message: "Scanned 142 SKUs — 8 low stock, 3 out of stock", timestamp: new Date(Date.now() - 180000), status: "done" },
  { id: 2, agentId: "monitor", agentName: "Inventory Monitor", toolId: "analyze_trends", toolLabel: "Analyze Trends", message: "BLK-TEE-M velocity: 87 units/week — reorder threshold will breach in 2 days", timestamp: new Date(Date.now() - 160000), status: "done" },
  { id: 3, agentId: "monitor", agentName: "Inventory Monitor", toolId: "send_notification", toolLabel: "Send Notification", message: "Triggered low-stock alert for 3 critical SKUs", timestamp: new Date(Date.now() - 140000), status: "done" },
  { id: 4, agentId: "drafter", agentName: "PO Drafter", toolId: "draft_email", toolLabel: "Draft Email", message: "Drafted PO #106 for Pacific Textile Co. — 3 line items, $2,710.00 total", timestamp: new Date(Date.now() - 120000), status: "done" },
  { id: 5, agentId: "drafter", agentName: "PO Drafter", toolId: "validate", toolLabel: "Validate", message: "Validated supplier email, pricing, and MOQ requirements", timestamp: new Date(Date.now() - 100000), status: "done" },
  { id: 6, agentId: "approver", agentName: "Approval Gate", toolId: "await_approval", toolLabel: "Await Approval", message: "PO #106 staged for review — waiting for human approval", timestamp: new Date(Date.now() - 80000), status: "waiting" },
  { id: 7, agentId: "scout", agentName: "Lead Scout", toolId: "search_suppliers", toolLabel: "Search Suppliers", message: "Found 3 new organic cotton suppliers in Portugal — avg lead time 18d", timestamp: new Date(Date.now() - 60000), status: "done" },
  { id: 8, agentId: "scout", agentName: "Lead Scout", toolId: "analyze_trends", toolLabel: "Analyze Trends", message: "Comparing GreenThread vs. new supplier EcoWeave — 25d vs 18d lead time", timestamp: new Date(Date.now() - 40000), status: "done" },
];

const INITIAL_CHAT: ChatMessage[] = [
  { id: 1, from: "Inventory Monitor", to: "PO Drafter", message: "3 SKUs critically low: BLK-TEE-M (4 units), WHT-HOODIE-L (2 units), GRY-JOGGER-XL (3 units). Recommend immediate reorder.", timestamp: new Date(Date.now() - 150000) },
  { id: 2, from: "PO Drafter", to: "Inventory Monitor", message: "Acknowledged. Pulling supplier pricing for Pacific Textile Co. Will draft PO with suggested quantities based on 30-day velocity.", timestamp: new Date(Date.now() - 130000) },
  { id: 3, from: "PO Drafter", to: "Approval Gate", message: "PO #106 ready for review. 3 line items totaling $2,710.00. Supplier: Pacific Textile Co. Expected delivery: April 1.", timestamp: new Date(Date.now() - 90000) },
  { id: 4, from: "Approval Gate", to: "PO Drafter", message: "Received. Holding for human approval. Will notify when approved or rejected.", timestamp: new Date(Date.now() - 85000) },
  { id: 5, from: "Lead Scout", to: "Inventory Monitor", message: "Found alternative supplier EcoWeave with 7-day faster lead time on organic cotton. Should I flag for next PO cycle?", timestamp: new Date(Date.now() - 50000) },
  { id: 6, from: "Inventory Monitor", to: "Lead Scout", message: "Yes, add to supplier pool. Also check if they can match GreenThread's GOTS certification.", timestamp: new Date(Date.now() - 30000) },
];

const INCOMING_EVENTS: Array<{ tool: ToolCall; chat?: ChatMessage }> = [
  {
    tool: { id: 0, agentId: "monitor", agentName: "Inventory Monitor", toolId: "check_inventory", toolLabel: "Check Inventory", message: "Cycle scan complete — NVY-CAP-OS restocked to 150 units", timestamp: new Date(), status: "done" },
    chat: { id: 0, from: "Inventory Monitor", to: "Lead Scout", message: "Navy Cap restocked via QuickShip. Monitor for velocity changes this week.", timestamp: new Date() },
  },
  {
    tool: { id: 0, agentId: "scout", agentName: "Lead Scout", toolId: "search_suppliers", toolLabel: "Search Suppliers", message: "Evaluating EcoWeave certification documents — GOTS cert confirmed", timestamp: new Date(), status: "done" },
  },
  {
    tool: { id: 0, agentId: "drafter", agentName: "PO Drafter", toolId: "draft_email", toolLabel: "Draft Email", message: "Drafting PO #107 for Urban Stitch MFG — denim jacket restock", timestamp: new Date(), status: "running" },
    chat: { id: 0, from: "PO Drafter", to: "Approval Gate", message: "Starting draft for PO #107 — Urban Stitch denim restock. Will send for approval shortly.", timestamp: new Date() },
  },
  {
    tool: { id: 0, agentId: "monitor", agentName: "Inventory Monitor", toolId: "analyze_trends", toolLabel: "Analyze Trends", message: "WHT-SNKR-9 trending +40% week-over-week — potential stockout in 5 days", timestamp: new Date(), status: "done" },
    chat: { id: 0, from: "Inventory Monitor", to: "PO Drafter", message: "Alert: White Low-Top Sneaker size 9 at risk. Current velocity suggests stockout by Friday. Queue SoleTech reorder.", timestamp: new Date() },
  },
  {
    tool: { id: 0, agentId: "drafter", agentName: "PO Drafter", toolId: "validate", toolLabel: "Validate", message: "PO #107 validated — 2 line items, $2,160.00 total", timestamp: new Date(), status: "done" },
  },
  {
    tool: { id: 0, agentId: "scout", agentName: "Lead Scout", toolId: "sync_data", toolLabel: "Sync Data", message: "Synced 2 new suppliers to directory: EcoWeave Textiles, Porto Denim Co.", timestamp: new Date(), status: "done" },
    chat: { id: 0, from: "Lead Scout", to: "Inventory Monitor", message: "2 new suppliers added to pool. EcoWeave confirmed GOTS. Porto Denim has competitive pricing on selvedge.", timestamp: new Date() },
  },
  {
    tool: { id: 0, agentId: "approver", agentName: "Approval Gate", toolId: "send_notification", toolLabel: "Send Notification", message: "Reminder: PO #106 still pending approval — 45 minutes elapsed", timestamp: new Date(), status: "waiting" },
  },
  {
    tool: { id: 0, agentId: "monitor", agentName: "Inventory Monitor", toolId: "check_inventory", toolLabel: "Check Inventory", message: "Scanning all 142 SKUs — cycle check initiated", timestamp: new Date(), status: "running" },
  },
];

/* ─── Helpers ─── */

function timeAgo(date: Date): string {
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000);
  if (seconds < 10) return "just now";
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ago`;
}

/* ─── Component ─── */

export default function AgentsPage() {
  const [feed, setFeed] = useState<ToolCall[]>(INITIAL_FEED);
  const [chat, setChat] = useState<ChatMessage[]>(INITIAL_CHAT);
  const [activeTools, setActiveTools] = useState<Set<string>>(new Set());
  const [agents, setAgents] = useState<Agent[]>(AGENTS);
  const eventIndex = useRef(0);
  const nextId = useRef(100);
  const feedEndRef = useRef<HTMLDivElement>(null);
  const chatEndRef = useRef<HTMLDivElement>(null);

  // Simulate live agent activity
  useEffect(() => {
    const interval = setInterval(() => {
      const idx = eventIndex.current % INCOMING_EVENTS.length;
      const event = INCOMING_EVENTS[idx];
      eventIndex.current++;

      const toolCall: ToolCall = {
        ...event.tool,
        id: nextId.current++,
        timestamp: new Date(),
      };

      // Light up the tool
      setActiveTools((prev) => new Set(prev).add(toolCall.toolId));
      setTimeout(() => {
        setActiveTools((prev) => {
          const next = new Set(prev);
          next.delete(toolCall.toolId);
          return next;
        });
      }, 2000);

      // Update agent status
      setAgents((prev) =>
        prev.map((a) =>
          a.id === toolCall.agentId
            ? { ...a, status: toolCall.status === "waiting" ? "waiting" : "running", currentTask: toolCall.message }
            : a
        )
      );

      setFeed((prev) => [...prev.slice(-30), toolCall]);

      if (event.chat) {
        const chatMsg: ChatMessage = {
          ...event.chat,
          id: nextId.current++,
          timestamp: new Date(),
        };
        setChat((prev) => [...prev.slice(-30), chatMsg]);
      }
    }, 3500);

    return () => clearInterval(interval);
  }, []);

  // Auto-scroll feeds
  useEffect(() => {
    feedEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [feed]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [chat]);

  const statusLabel = (s: Agent["status"]) => {
    if (s === "running") return "Running";
    if (s === "waiting") return "Awaiting";
    return "Idle";
  };

  const statusDot = (s: string) => {
    if (s === "running") return "status-dot--ok";
    if (s === "waiting") return "status-dot--warning";
    if (s === "done") return "status-dot--neutral";
    return "status-dot--neutral";
  };

  return (
    <div className="bento-page">
      <PageHeader title="Agents">
        <span className="agent-live-dot" />
        <span className="bento-sync-status">Live — {agents.filter((a) => a.status === "running").length} active</span>
      </PageHeader>

      {/* ── Top Row: Activity Feed + Agent Chat ── */}
      <div className="agent-grid-top">
        {/* Activity Feed — takes 2/3 */}
        <div className="grid-card agent-feed-card">
          <div className="grid-card-header">
            <div>
              <div className="grid-card-title">
                <Flow size={16} style={{ marginRight: 6, opacity: 0.5 }} />
                Activity Feed
              </div>
              <div className="grid-card-desc">Real-time tool calls across all agents</div>
            </div>
            <CountBadge count={feed.length} label="events" />
          </div>
          <div className="agent-feed-scroll">
            {feed.map((item) => (
              <div
                key={item.id}
                className={`agent-feed-item${item.status === "running" ? " agent-feed-item--active" : ""}${item.status === "waiting" ? " agent-feed-item--waiting" : ""}`}
              >
                <div className="agent-feed-dot-col">
                  <span className={`agent-feed-dot ${statusDot(item.status)}`} />
                  <span className="agent-feed-line" />
                </div>
                <div className="agent-feed-content">
                  <div className="agent-feed-meta">
                    <span className="agent-feed-agent">{item.agentName}</span>
                    <span className="agent-feed-tool">{item.toolLabel}</span>
                    <span className="agent-feed-time">{timeAgo(item.timestamp)}</span>
                  </div>
                  <div className="agent-feed-msg">{item.message}</div>
                </div>
              </div>
            ))}
            <div ref={feedEndRef} />
          </div>
        </div>

        {/* Agent Chat — takes 1/3 */}
        <div className="grid-card agent-chat-card">
          <div className="grid-card-header">
            <div>
              <div className="grid-card-title">
                <Chat size={16} style={{ marginRight: 6, opacity: 0.5 }} />
                Agent Comms
              </div>
              <div className="grid-card-desc">Inter-agent coordination</div>
            </div>
          </div>
          <div className="agent-chat-scroll">
            {chat.map((msg) => (
              <div key={msg.id} className="agent-chat-msg">
                <div className="agent-chat-bubble">
                  <div className="agent-chat-route">
                    <span className="agent-chat-from">{msg.from}</span>
                    <Connect size={12} />
                    <span className="agent-chat-to">{msg.to}</span>
                  </div>
                  <div className="agent-chat-text">{msg.message}</div>
                </div>
                <div className="agent-chat-time">{timeAgo(msg.timestamp)}</div>
              </div>
            ))}
            <div ref={chatEndRef} />
          </div>
        </div>
      </div>

      {/* ── Bottom Row: Agent Cards + Tool Registry ── */}
      <div className="agent-grid-bottom">
        {/* Agent Cards */}
        <div className="agent-cards">
          {agents.map((agent) => {
            const Icon = agent.icon;
            return (
              <div key={agent.id} className={`grid-card agent-card agent-card--${agent.status}`}>
                <div className="agent-card-top">
                  <span className="agent-card-icon">
                    <Icon size={20} />
                  </span>
                  <span className={`agent-status-pill agent-status-pill--${agent.status}`}>
                    {agent.status === "running" && <Play size={10} />}
                    {agent.status === "waiting" && <Pause size={10} />}
                    {agent.status === "idle" && <span className="agent-idle-dot" />}
                    {statusLabel(agent.status)}
                  </span>
                </div>
                <div className="agent-card-name">{agent.name}</div>
                <div className="agent-card-role">{agent.role}</div>
                <div className="agent-card-task">
                  {agent.status === "running" && <Lightning size={12} className="agent-pulse" />}
                  {agent.status === "waiting" && <WarningAlt size={12} />}
                  <span>{agent.currentTask}</span>
                </div>
              </div>
            );
          })}
        </div>

        {/* Tool Registry */}
        <div className="grid-card agent-tools-card">
          <div className="grid-card-header">
            <div>
              <div className="grid-card-title">
                <Catalog size={16} style={{ marginRight: 6, opacity: 0.5 }} />
                Tool Registry
              </div>
              <div className="grid-card-desc">Available tools — lights up on use</div>
            </div>
          </div>
          <div className="agent-tools-grid">
            {TOOLS.map((tool) => {
              const Icon = tool.icon;
              const isActive = activeTools.has(tool.id);
              return (
                <div key={tool.id} className={`agent-tool-item${isActive ? " agent-tool-item--active" : ""}`}>
                  <span className="agent-tool-icon">
                    <Icon size={18} />
                  </span>
                  <span className="agent-tool-label">{tool.label}</span>
                  {isActive && <span className="agent-tool-pulse" />}
                </div>
              );
            })}
          </div>
          <div className="agent-tools-stats">
            <div className="agent-tools-stat">
              <span className="agent-tools-stat-value">{feed.filter((f) => f.status === "done").length}</span>
              <span className="agent-tools-stat-label">Completed</span>
            </div>
            <div className="agent-tools-stat">
              <span className="agent-tools-stat-value">{feed.filter((f) => f.status === "running").length}</span>
              <span className="agent-tools-stat-label">In Progress</span>
            </div>
            <div className="agent-tools-stat">
              <span className="agent-tools-stat-value">{feed.filter((f) => f.status === "waiting").length}</span>
              <span className="agent-tools-stat-label">Pending</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
