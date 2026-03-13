import { useState, useRef, useId, useEffect, useCallback } from "react";
import {
  motion,
  useScroll,
  useTransform,
  useInView,
  useReducedMotion,
} from "framer-motion";

/* ── Reusable scroll-reveal wrapper ── */
function Reveal({
  children,
  delay = 0,
  className = "",
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "-60px" });
  const prefersReduced = useReducedMotion();

  return (
    <motion.div
      ref={ref}
      className={className}
      style={{ width: "100%" }}
      initial={prefersReduced ? false : { opacity: 0, y: 28 }}
      animate={inView ? { opacity: 1, y: 0 } : { opacity: 0, y: 28 }}
      transition={prefersReduced ? { duration: 0 } : { duration: 0.6, delay, ease: [0.25, 0.1, 0.25, 1] }}
    >
      {children}
    </motion.div>
  );
}

/* ── Staggered list wrapper ── */
function StaggerList({
  children,
  className = "",
}: {
  children: React.ReactNode;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "-40px" });
  const prefersReduced = useReducedMotion();

  return (
    <motion.div
      ref={ref}
      className={className}
      style={{ width: "100%" }}
      initial="hidden"
      animate={inView ? "visible" : "hidden"}
      variants={{
        visible: { transition: { staggerChildren: prefersReduced ? 0 : 0.1 } },
        hidden: {},
      }}
    >
      {children}
    </motion.div>
  );
}

const staggerChild = {
  hidden: { opacity: 0, y: 24 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.25, 0.1, 0.25, 1] as const },
  },
};

/* ── SVG draw-on transition ── */
const drawEase = [0.33, 0, 0.2, 1] as const;
const draw = {
  hidden: { pathLength: 0, opacity: 0 },
  visible: (i: number) => ({
    pathLength: 1,
    opacity: 1,
    transition: {
      pathLength: { delay: 0.2 + i * 0.15, duration: 0.8, ease: drawEase },
      opacity: { delay: 0.2 + i * 0.15, duration: 0.01 },
    },
  }),
};

/* ── Feature icon illustrations (line-art, draw-on-scroll) ── */
function FeatureIcon({ id, inView, reduced }: { id: string; inView: boolean; reduced: boolean | null }) {
  const animate = reduced ? "visible" : inView ? "visible" : "hidden";
  const props = { fill: "none", stroke: "currentColor", strokeWidth: 1.5, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

  switch (id) {
    case "alerts":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Bell body */}
          <motion.path d="M22 40h12M20 34h16c1.1 0 2-.9 2-2v-8a10 10 0 00-20 0v8c0 1.1.9 2 2 2z" {...props} variants={draw} custom={0} />
          {/* Notification ring 1 */}
          <motion.path d="M42 18a14 14 0 00-4-6" {...props} strokeDasharray="2 3" variants={draw} custom={1} />
          {/* Notification ring 2 */}
          <motion.path d="M14 18a14 14 0 014-6" {...props} strokeDasharray="2 3" variants={draw} custom={2} />
        </motion.svg>
      );
    case "ai-orders":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Document */}
          <motion.rect x="14" y="10" width="28" height="36" rx="3" {...props} variants={draw} custom={0} />
          {/* Lines */}
          <motion.path d="M20 20h16M20 26h12M20 32h8" {...props} variants={draw} custom={1} />
          {/* Checkmark circle */}
          <motion.circle cx="38" cy="38" r="8" {...props} fill="#FAFBFC" variants={draw} custom={2} />
          <motion.path d="M34 38l3 3 5-6" {...props} variants={draw} custom={3} />
        </motion.svg>
      );
    case "reports":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Axes */}
          <motion.path d="M12 44V14M12 44h32" {...props} variants={draw} custom={0} />
          {/* Bars (grow up) */}
          <motion.path d="M20 44V32" {...props} strokeWidth={4} variants={draw} custom={1} />
          <motion.path d="M28 44V26" {...props} strokeWidth={4} variants={draw} custom={2} />
          <motion.path d="M36 44V20" {...props} strokeWidth={4} variants={draw} custom={3} />
          {/* Trend line */}
          <motion.path d="M18 30l10-8 10 4" {...props} strokeDasharray="2 3" variants={draw} custom={4} />
        </motion.svg>
      );
    case "suppliers":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Node circles */}
          <motion.circle cx="28" cy="16" r="5" {...props} variants={draw} custom={0} />
          <motion.circle cx="16" cy="38" r="5" {...props} variants={draw} custom={1} />
          <motion.circle cx="40" cy="38" r="5" {...props} variants={draw} custom={2} />
          {/* Connecting lines */}
          <motion.path d="M25 20l-6 14M31 20l6 14M20 38h16" {...props} strokeDasharray="3 3" variants={draw} custom={3} />
        </motion.svg>
      );
    case "customers":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Person */}
          <motion.circle cx="28" cy="18" r="6" {...props} variants={draw} custom={0} />
          <motion.path d="M18 42c0-5.5 4.5-10 10-10s10 4.5 10 10" {...props} variants={draw} custom={1} />
          {/* DNA-like helix */}
          <motion.path d="M42 14c-4 4-4 8 0 12s0 8-4 12" {...props} strokeDasharray="2 3" variants={draw} custom={2} />
          <motion.path d="M46 14c-4 4-4 8 0 12s0 8-4 12" {...props} strokeDasharray="2 3" variants={draw} custom={3} />
        </motion.svg>
      );
    case "gdpr":
      return (
        <motion.svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true" initial="hidden" animate={animate}>
          {/* Shield */}
          <motion.path d="M28 8l16 6v14c0 10-8 16-16 20-8-4-16-10-16-20V14l16-6z" {...props} variants={draw} custom={0} />
          {/* Checkmark */}
          <motion.path d="M22 28l4 4 8-10" {...props} variants={draw} custom={1} />
        </motion.svg>
      );
    default:
      return null;
  }
}

/* ── Single feature card with draw-on icon ── */
function FeatureCard({ feature, index }: { feature: typeof FEATURES[number]; index: number }) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, margin: "-80px" });
  const prefersReduced = useReducedMotion();

  return (
    <motion.div
      ref={ref}
      className="em-fcard"
      variants={staggerChild}
      whileHover={prefersReduced ? undefined : { y: -4 }}
      transition={{ duration: 0.25, ease: [0.25, 0.1, 0.25, 1] }}
    >
      <div className="em-fcard__icon">
        <FeatureIcon id={feature.iconId} inView={inView} reduced={prefersReduced} />
      </div>
      <span className="em-fcard__num">{String(index + 1).padStart(2, "0")}</span>
      <h3 className="em-fcard__title">{feature.title}</h3>
      <p className="em-fcard__desc">{feature.desc}</p>
    </motion.div>
  );
}

/* ── Inline arrow for primary buttons ── */
function ArrowRight() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true" style={{ marginLeft: 6 }}>
      <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}

/* ── Section arrows divider ── */
function SectionArrows() {
  return (
    <div className="em-arrows" aria-hidden="true">
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 2v12M4 10l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 2v12M4 10l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 2v12M4 10l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
    </div>
  );
}

/* ── Image placeholder ── */
function ImagePlaceholder({ aspect = "16/10", label }: { aspect?: string; label?: string }) {
  return (
    <div className="em-img-placeholder" style={{ aspectRatio: aspect }} role="img" aria-label={label || "Placeholder image"}>
      <svg width="48" height="48" viewBox="0 0 48 48" fill="none" aria-hidden="true">
        <rect x="4" y="8" width="40" height="32" rx="4" stroke="currentColor" strokeWidth="1.5"/>
        <circle cx="16" cy="20" r="4" stroke="currentColor" strokeWidth="1.5"/>
        <path d="M4 32l12-10 8 6 8-6 12 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      {label && <span className="em-img-placeholder__label">{label}</span>}
    </div>
  );
}

/* ── Hero interactive graphic — live agent network ── */
const HERO_AGENTS = [
  { id: "monitor", label: "Monitor", x: 50, y: 12, icon: "M3 9h2v6H3zM7 7h2v8H7zM11 5h2v10h-2z" },
  { id: "drafter", label: "PO Drafter", x: 88, y: 40, icon: "M4 2h8v12H4zM6 5h4M6 7h3M6 9h2" },
  { id: "scout", label: "Lead Scout", x: 50, y: 72, icon: "M8 2l6 3v5c0 3-3 5-6 6-3-1-6-3-6-6V5l6-3z" },
  { id: "gate", label: "Approval", x: 12, y: 40, icon: "M2 8a6 6 0 1112 0A6 6 0 012 8zM6 8l2 2 4-5" },
] as const;

const HERO_CONNECTIONS = [
  { from: 0, to: 1, label: "3 SKUs low" },
  { from: 1, to: 2, label: "find supplier" },
  { from: 2, to: 3, label: "best match" },
  { from: 3, to: 0, label: "approved" },
] as const;

function HeroGraphic() {
  const prefersReduced = useReducedMotion();
  const [activeConn, setActiveConn] = useState(-1);
  const [activeAgent, setActiveAgent] = useState(-1);
  const [pulseItems, setPulseItems] = useState<{ id: number; x: number; y: number; label: string }[]>([]);
  const cycleRef = useRef(0);

  useEffect(() => {
    if (prefersReduced) {
      setActiveConn(-1);
      setActiveAgent(0);
      setPulseItems(HERO_CONNECTIONS.map((c, i) => ({
        id: i,
        x: (HERO_AGENTS[c.from].x + HERO_AGENTS[c.to].x) / 2,
        y: (HERO_AGENTS[c.from].y + HERO_AGENTS[c.to].y) / 2,
        label: c.label,
      })));
      return;
    }

    const step = () => {
      const idx = cycleRef.current % HERO_CONNECTIONS.length;
      const conn = HERO_CONNECTIONS[idx];
      setActiveConn(idx);
      setActiveAgent(conn.from);

      const midX = (HERO_AGENTS[conn.from].x + HERO_AGENTS[conn.to].x) / 2;
      const midY = (HERO_AGENTS[conn.from].y + HERO_AGENTS[conn.to].y) / 2;
      setPulseItems((prev) => [...prev.slice(-3), { id: Date.now(), x: midX, y: midY, label: conn.label }]);

      setTimeout(() => setActiveAgent(conn.to), 600);
      cycleRef.current++;
    };

    step();
    const interval = setInterval(step, 2200);
    return () => clearInterval(interval);
  }, [prefersReduced]);

  return (
    <div className="em-hero-graphic" aria-hidden="true">
      {/* Connection lines */}
      <svg className="em-hero-graphic__lines" viewBox="0 0 100 84" preserveAspectRatio="xMidYMid meet">
        {HERO_CONNECTIONS.map((conn, i) => {
          const from = HERO_AGENTS[conn.from];
          const to = HERO_AGENTS[conn.to];
          return (
            <motion.line
              key={i}
              x1={from.x}
              y1={from.y}
              x2={to.x}
              y2={to.y}
              stroke={activeConn === i ? "var(--color-text)" : "var(--color-stroke-light)"}
              strokeWidth={activeConn === i ? 0.6 : 0.35}
              strokeDasharray={activeConn === i ? "none" : "2 2"}
              transition={{ duration: 0.3 }}
            />
          );
        })}
      </svg>

      {/* Pulse labels on connections */}
      {pulseItems.slice(-4).map((item) => (
        <motion.div
          key={item.id}
          className="em-hero-graphic__pulse-label"
          style={{ left: `${item.x}%`, top: `${item.y}%` }}
          initial={prefersReduced ? { opacity: 0.7 } : { opacity: 0, scale: 0.7 }}
          animate={{ opacity: 0.7, scale: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.4 }}
        >
          {item.label}
        </motion.div>
      ))}

      {/* Agent nodes */}
      {HERO_AGENTS.map((agent, i) => (
        <motion.div
          key={agent.id}
          className={`em-hero-graphic__node${activeAgent === i ? " em-hero-graphic__node--active" : ""}`}
          style={{ left: `${agent.x}%`, top: `${agent.y}%` }}
          initial={prefersReduced ? false : { opacity: 0, scale: 0.5 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={prefersReduced ? { duration: 0 } : { duration: 0.5, delay: 0.4 + i * 0.15 }}
        >
          <div className="em-hero-graphic__node-icon">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <path d={agent.icon} stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <span className="em-hero-graphic__node-label">{agent.label}</span>
          {activeAgent === i && !prefersReduced && (
            <motion.div
              className="em-hero-graphic__node-ring"
              initial={{ scale: 0.8, opacity: 0.6 }}
              animate={{ scale: 1.6, opacity: 0 }}
              transition={{ duration: 1.2, repeat: Infinity }}
            />
          )}
        </motion.div>
      ))}

      {/* Center status */}
      <div className="em-hero-graphic__center">
        <div className="em-hero-graphic__center-icon">
          <BrandLogo size={20} />
        </div>
        <span className="em-hero-graphic__center-label">Command Center</span>
      </div>
    </div>
  );
}

/* ── FAQ item ── */
function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  const id = useId();
  const panelId = `faq-panel-${id}`;
  const buttonId = `faq-btn-${id}`;

  return (
    <div className={`em-faq-item${open ? " em-faq-item--open" : ""}`}>
      <button
        id={buttonId}
        className="em-faq-item__q"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
        aria-controls={panelId}
      >
        <span>{q}</span>
        <span className="em-faq-item__toggle" aria-hidden="true">{open ? "\u2212" : "+"}</span>
      </button>
      <div
        id={panelId}
        role="region"
        aria-labelledby={buttonId}
        hidden={!open}
      >
        {open && <p className="em-faq-item__a">{a}</p>}
      </div>
    </div>
  );
}

/* ── Brand logo SVG (reusable, uses currentColor) ── */
function BrandLogo({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 28 28" fill="none" aria-hidden="true">
      <rect x="2" y="2" width="24" height="24" rx="6" stroke="currentColor" strokeWidth="1.5" />
      <rect x="7" y="14" width="4" height="8" rx="1" fill="currentColor" />
      <rect x="12" y="10" width="4" height="12" rx="1" fill="var(--color-stroke)" />
      <rect x="17" y="6" width="4" height="16" rx="1" fill="currentColor" />
    </svg>
  );
}

/* ═══════════════════════════════════════
   LANDING PAGE
   ═══════════════════════════════════════ */

/* ═══════════════════════════════════════
   INTERACTIVE STEPS — "How it works"
   ═══════════════════════════════════════ */

const STEP_DATA = [
  { num: "01", title: "Connect your store", desc: "Install and sync in under 60 seconds." },
  { num: "02", title: "Set your rules", desc: "Configure thresholds and alerts." },
  { num: "03", title: "Agents take over", desc: "Four AI agents start working autonomously." },
  { num: "04", title: "Review everything", desc: "PO copy, invoices, reports, leads — all in one place." },
];

/* Step 1: Animated store connection */
function StepConnect() {
  const [phase, setPhase] = useState<"idle" | "syncing" | "done">("idle");
  const [progress, setProgress] = useState(0);
  const [synced, setSynced] = useState(0);
  const prefersReduced = useReducedMotion();

  const handleConnect = useCallback(() => {
    if (phase !== "idle") return;
    setPhase("syncing");
    setProgress(0);
    setSynced(0);
  }, [phase]);

  useEffect(() => {
    if (phase !== "syncing") return;
    const interval = setInterval(() => {
      setProgress((p) => {
        const next = p + (prefersReduced ? 50 : 3 + Math.random() * 5);
        if (next >= 100) {
          clearInterval(interval);
          setPhase("done");
          setSynced(847);
          return 100;
        }
        setSynced(Math.floor((next / 100) * 847));
        return next;
      });
    }, prefersReduced ? 50 : 60);
    return () => clearInterval(interval);
  }, [phase, prefersReduced]);

  const reset = () => { setPhase("idle"); setProgress(0); setSynced(0); };

  return (
    <div className="em-step-demo">
      <div className="em-step-demo__mock">
        <div className="em-step-demo__mock-bar" aria-hidden="true">
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
        </div>
        <div className="em-step-demo__body">
          {phase === "idle" && (
            <div className="em-step-demo__center">
              <BrandLogo size={36} />
              <p className="em-step-demo__label">Connect your Shopify store</p>
              <button className="em-btn em-btn--primary" onClick={handleConnect} type="button">
                Connect store <ArrowRight />
              </button>
            </div>
          )}
          {phase === "syncing" && (
            <div className="em-step-demo__center">
              <p className="em-step-demo__label">Syncing products&hellip;</p>
              <div className="em-step-demo__progress">
                <motion.div
                  className="em-step-demo__progress-fill"
                  style={{ width: `${progress}%` }}
                  layout
                />
              </div>
              <div className="em-step-demo__meta">
                <span>{synced} products</span>
                <span>{Math.round(progress)}%</span>
              </div>
            </div>
          )}
          {phase === "done" && (
            <div className="em-step-demo__center">
              <motion.div
                initial={prefersReduced ? false : { scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ duration: 0.3 }}
              >
                <svg width="40" height="40" viewBox="0 0 40 40" fill="none" aria-hidden="true">
                  <circle cx="20" cy="20" r="18" stroke="var(--color-status-ok)" strokeWidth="1.5" />
                  <path d="M14 20l4 4 8-10" stroke="var(--color-status-ok)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </motion.div>
              <p className="em-step-demo__label">847 products synced</p>
              <p className="em-step-demo__sublabel">3 locations &middot; 2,431 variants</p>
              <button className="em-btn em-btn--sm" onClick={reset} type="button">Run again</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

/* Step 2: Interactive configuration */
function StepConfigure() {
  const [threshold, setThreshold] = useState(15);
  const [email, setEmail] = useState("");
  const [alerts, setAlerts] = useState(true);
  const [reports, setReports] = useState(true);

  return (
    <div className="em-step-demo">
      <div className="em-step-demo__mock">
        <div className="em-step-demo__mock-bar" aria-hidden="true">
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
        </div>
        <div className="em-step-demo__body em-step-demo__body--form">
          <div className="em-step-demo__field">
            <label className="em-step-demo__field-label" htmlFor="demo-threshold">
              Low stock threshold
            </label>
            <div className="em-step-demo__slider-row">
              <input
                id="demo-threshold"
                type="range"
                min={1}
                max={50}
                value={threshold}
                onChange={(e) => setThreshold(Number(e.target.value))}
                className="em-step-demo__slider"
              />
              <span className="em-step-demo__slider-val">{threshold} units</span>
            </div>
          </div>

          <div className="em-step-demo__field">
            <label className="em-step-demo__field-label" htmlFor="demo-email">
              Alert email
            </label>
            <input
              id="demo-email"
              type="email"
              className="em-step-demo__input"
              placeholder="you@company.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="off"
            />
          </div>

          <div className="em-step-demo__toggles">
            <label className="em-step-demo__toggle">
              <input
                type="checkbox"
                checked={alerts}
                onChange={(e) => setAlerts(e.target.checked)}
              />
              <span className="em-step-demo__toggle-track">
                <span className="em-step-demo__toggle-thumb" />
              </span>
              <span className="em-step-demo__toggle-text">Low stock alerts</span>
            </label>
            <label className="em-step-demo__toggle">
              <input
                type="checkbox"
                checked={reports}
                onChange={(e) => setReports(e.target.checked)}
              />
              <span className="em-step-demo__toggle-track">
                <span className="em-step-demo__toggle-thumb" />
              </span>
              <span className="em-step-demo__toggle-text">Weekly reports</span>
            </label>
          </div>

          <div className="em-step-demo__summary">
            Alert when stock drops below <strong>{threshold}</strong> units
            {email ? <> &middot; Notify <strong>{email}</strong></> : null}
          </div>
        </div>
      </div>
    </div>
  );
}

/* Step 4: Review hub with inner tabs */
/* Inline SVG icons for review tabs */
function TabIconCopy() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
      <rect x="2" y="1.5" width="10" height="11" rx="1.5" stroke="currentColor" strokeWidth="1.2" />
      <path d="M4.5 5h5M4.5 7h4M4.5 9h2.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
    </svg>
  );
}

function TabIconInvoice() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
      <path d="M3 2.5h8v10l-1.5-1-1.5 1-1.5-1-1.5 1-1.5-1L3 12.5v-10z" stroke="currentColor" strokeWidth="1.2" strokeLinejoin="round" />
      <path d="M5.5 5h3M5.5 7h2" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" />
    </svg>
  );
}

function TabIconReport() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
      <path d="M2.5 11V4M5.5 11V6M8.5 11V3M11.5 11V7" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" />
    </svg>
  );
}

function TabIconLead() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
      <circle cx="4" cy="4" r="2" stroke="currentColor" strokeWidth="1.2" />
      <circle cx="10" cy="4" r="2" stroke="currentColor" strokeWidth="1.2" />
      <circle cx="7" cy="10.5" r="2" stroke="currentColor" strokeWidth="1.2" />
      <path d="M5.2 5.6L6 8.5M8.8 5.6L8 8.5" stroke="currentColor" strokeWidth="1.2" strokeLinecap="round" strokeDasharray="1.5 2" />
    </svg>
  );
}

const REVIEW_TABS: { label: string; icon: React.FC }[] = [
  { label: "Copy Review", icon: TabIconCopy },
  { label: "Invoices", icon: TabIconInvoice },
  { label: "Reports", icon: TabIconReport },
  { label: "Lead Analysis", icon: TabIconLead },
];

function StepReview() {
  const [tab, setTab] = useState(0);

  return (
    <div className="em-step-demo">
      <div className="em-step-demo__mock">
        <div className="em-step-demo__mock-bar" aria-hidden="true">
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
        </div>
        <div className="em-step-demo__body em-step-demo__body--review">
          <div className="em-review-tabs" role="tablist" aria-label="Review categories">
            {REVIEW_TABS.map(({ label, icon: Icon }, i) => (
              <button
                key={label}
                role="tab"
                aria-selected={i === tab}
                className={`em-review-tab${i === tab ? " em-review-tab--active" : ""}`}
                onClick={() => setTab(i)}
                type="button"
              >
                <Icon />
                {label}
              </button>
            ))}
          </div>
          <div className="em-review-content" role="tabpanel">
            {tab === 0 && <ReviewCopy />}
            {tab === 1 && <ReviewInvoices />}
            {tab === 2 && <ReviewReports />}
            {tab === 3 && <ReviewLeads />}
          </div>
        </div>
      </div>
    </div>
  );
}

function ReviewCopy() {
  return (
    <div className="em-review-doc">
      <div className="em-review-doc__header">
        <span className="em-review-doc__badge">Draft</span>
        <span className="em-review-doc__id">PO #1847</span>
      </div>
      <div className="em-review-doc__letter">
        <p className="em-review-doc__to">To: <strong>Lumino Supply Co.</strong></p>
        <p className="em-review-doc__body">
          Please supply 200 units of Vanilla Bean Candle (Large) at the agreed rate
          of $4.20/unit. Delivery requested within 7 business days to Warehouse A.
        </p>
        <p className="em-review-doc__body">
          Total: <strong>$840.00</strong> &middot; Net 30 terms
        </p>
      </div>
      <div className="em-review-doc__actions">
        <button className="em-btn em-btn--primary em-btn--sm" type="button">Approve &amp; send</button>
        <button className="em-btn em-btn--sm" type="button">Edit draft</button>
      </div>
    </div>
  );
}

function ReviewInvoices() {
  const invoices = [
    { id: "INV-2041", supplier: "Lumino Supply Co.", amount: "$840.00", status: "pending", date: "Mar 10" },
    { id: "INV-2038", supplier: "Driftwood Textiles", amount: "$1,260.00", status: "paid", date: "Mar 7" },
    { id: "INV-2035", supplier: "Solis Fabric Ltd.", amount: "$2,100.00", status: "paid", date: "Mar 3" },
  ];

  return (
    <div className="em-review-list">
      {invoices.map((inv) => (
        <div key={inv.id} className="em-review-list__row">
          <div className="em-review-list__primary">
            <span className="em-review-list__id">{inv.id}</span>
            <span className="em-review-list__name">{inv.supplier}</span>
          </div>
          <div className="em-review-list__secondary">
            <span className="em-review-list__amount">{inv.amount}</span>
            <span className={`em-review-list__status em-review-list__status--${inv.status}`}>{inv.status}</span>
            <span className="em-review-list__date">{inv.date}</span>
          </div>
        </div>
      ))}
    </div>
  );
}

function ReviewReports() {
  return (
    <div className="em-review-doc">
      <div className="em-review-doc__header">
        <span className="em-review-doc__badge">Weekly</span>
        <span className="em-review-doc__id">Mar 3 &ndash; Mar 10</span>
      </div>
      <div className="em-review-doc__metrics">
        <div className="em-review-metric">
          <span className="em-review-metric__value">847</span>
          <span className="em-review-metric__label">Products tracked</span>
        </div>
        <div className="em-review-metric">
          <span className="em-review-metric__value">3</span>
          <span className="em-review-metric__label">Low stock alerts</span>
        </div>
        <div className="em-review-metric">
          <span className="em-review-metric__value">$840</span>
          <span className="em-review-metric__label">POs drafted</span>
        </div>
        <div className="em-review-metric">
          <span className="em-review-metric__value">0</span>
          <span className="em-review-metric__label">Stockouts</span>
        </div>
      </div>
      <p className="em-review-doc__summary">
        Inventory Monitor flagged 3 SKUs below threshold. PO Drafter generated 1 order.
        No stockouts this period. Lead Scout identified 2 alternative suppliers.
      </p>
    </div>
  );
}

function ReviewLeads() {
  const leads = [
    { supplier: "Lumino Supply Co.", lead: "7d", price: "$4.20/unit", score: 94, recommended: true },
    { supplier: "BrightWick Wholesale", lead: "12d", price: "$3.85/unit", score: 87, recommended: false },
    { supplier: "CandleCraft Direct", lead: "5d", price: "$4.90/unit", score: 91, recommended: false },
  ];

  return (
    <div className="em-review-leads">
      <div className="em-review-leads__agent-bar">
        <span className="em-review-leads__agent-icon" aria-hidden="true">
          <TabIconLead />
        </span>
        <span className="em-review-leads__agent-label">Lead Scout agent</span>
        <span className="em-review-leads__agent-status">Analyzed 3 suppliers for LUM-CNDL-04</span>
      </div>
      <div className="em-review-list">
        <div className="em-review-list__header">
          <span>Supplier</span>
          <span>Lead time</span>
          <span>Price</span>
          <span>Agent score</span>
        </div>
        {leads.map((lead) => (
          <div key={lead.supplier} className={`em-review-list__row em-review-list__row--grid${lead.recommended ? " em-review-list__row--recommended" : ""}`}>
            <div className="em-review-list__name-cell">
              <span className="em-review-list__name">{lead.supplier}</span>
              {lead.recommended && <span className="em-review-list__rec-badge">Recommended</span>}
            </div>
            <span className="em-review-list__cell">{lead.lead}</span>
            <span className="em-review-list__cell">{lead.price}</span>
            <div className="em-review-list__score-cell">
              <div className="em-review-list__score-bar">
                <div className="em-review-list__score-fill" style={{ width: `${lead.score}%` }} />
              </div>
              <span className="em-review-list__score">{lead.score}</span>
            </div>
          </div>
        ))}
      </div>
      <div className="em-review-leads__rec">
        <span className="em-review-leads__rec-icon" aria-hidden="true">
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none"><path d="M2 6l3 3 5-6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
        </span>
        <span>Agent recommends <strong>Lumino Supply Co.</strong> — best balance of price, lead time, and reliability.</span>
      </div>
    </div>
  );
}

/* Step 4: Agent activity feed */
function StepAgents() {
  const prefersReduced = useReducedMotion();
  const [visibleCount, setVisibleCount] = useState(0);
  const [replaying, setReplaying] = useState(false);

  const agentMessages = [
    { from: "Inventory Monitor", to: "System", text: "Scanning 847 products across 3 locations\u2026", time: "09:01", color: "var(--color-text-secondary)" },
    { from: "Inventory Monitor", to: "PO Drafter", text: "3 SKUs critically low \u2014 flagged for reorder", time: "09:01", color: "var(--color-status-critical)" },
    { from: "PO Drafter", to: "Lead Scout", text: "Need supplier pricing for LUM-CNDL-04, DRF-BAG-12", time: "09:02", color: "var(--color-text-secondary)" },
    { from: "Lead Scout", to: "PO Drafter", text: "Best match: Lumino Supply Co \u2014 $4.20/unit, 7d lead", time: "09:02", color: "var(--color-text-secondary)" },
    { from: "PO Drafter", to: "Approval Gate", text: "PO #1847 drafted \u2014 200 units, $840 total", time: "09:03", color: "var(--color-text-secondary)" },
    { from: "Approval Gate", to: "You", text: "PO #1847 staged for review. One click to approve.", time: "09:03", color: "var(--color-status-ok)" },
  ];

  useEffect(() => {
    if (prefersReduced) {
      setVisibleCount(agentMessages.length);
      return;
    }
    setVisibleCount(0);
    const timers: ReturnType<typeof setTimeout>[] = [];
    agentMessages.forEach((_, i) => {
      timers.push(setTimeout(() => setVisibleCount(i + 1), (i + 1) * 700));
    });
    return () => timers.forEach(clearTimeout);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefersReduced, replaying]);

  const handleReplay = () => {
    setVisibleCount(0);
    setReplaying((r) => !r);
  };

  return (
    <div className="em-step-demo">
      <div className="em-step-demo__mock">
        <div className="em-step-demo__mock-bar" aria-hidden="true">
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__dot" />
          <span className="em-step-demo__bar-status">
            <span className="em-step-demo__pulse" />
            Agents active
          </span>
        </div>
        <div className="em-step-demo__body em-step-demo__body--agents">
          <div className="em-step-demo__agent-feed" role="log" aria-label="Agent activity feed">
            {agentMessages.slice(0, visibleCount).map((msg, i) => (
              <motion.div
                key={i}
                className="em-step-demo__agent-msg"
                initial={prefersReduced ? false : { opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.25 }}
              >
                <span className="em-step-demo__agent-time">{msg.time}</span>
                <span className="em-step-demo__agent-route">
                  <span className="em-step-demo__agent-name">{msg.from}</span>
                  <span className="em-step-demo__agent-arrow" aria-hidden="true">&rarr;</span>
                  <span className="em-step-demo__agent-name">{msg.to}</span>
                </span>
                <span className="em-step-demo__agent-text" style={{ color: msg.color }}>{msg.text}</span>
              </motion.div>
            ))}
            {visibleCount === 0 && (
              <div className="em-step-demo__agent-waiting">
                <span className="em-step-demo__pulse" />
                <span>Initializing agents&hellip;</span>
              </div>
            )}
          </div>
          {visibleCount >= agentMessages.length && (
            <div className="em-step-demo__dash-footer">
              <span>All agents completed &middot; 1 PO awaiting approval</span>
              <button className="em-btn em-btn--sm" onClick={handleReplay} type="button">Replay</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

/* Interactive step selector */
function InteractiveSteps() {
  const [active, setActive] = useState(0);
  const panels = [<StepConnect key="connect" />, <StepConfigure key="configure" />, <StepAgents key="agents" />, <StepReview key="review" />];

  return (
    <div className="em-isteps">
      <div className="em-isteps__nav" role="tablist" aria-label="Setup steps">
        {STEP_DATA.map((step, i) => (
          <button
            key={step.num}
            role="tab"
            aria-selected={i === active}
            aria-controls={`step-panel-${i}`}
            className={`em-isteps__tab${i === active ? " em-isteps__tab--active" : ""}`}
            onClick={() => setActive(i)}
            type="button"
          >
            <span className="em-isteps__tab-num">{step.num}</span>
            <div className="em-isteps__tab-text">
              <span className="em-isteps__tab-title">{step.title}</span>
              <span className="em-isteps__tab-desc">{step.desc}</span>
            </div>
          </button>
        ))}
      </div>
      <div className="em-isteps__panel" id={`step-panel-${active}`} role="tabpanel">
        {panels[active]}
      </div>
    </div>
  );
}

const FEATURES = [
  {
    iconId: "alerts",
    title: "Inventory Monitor agent",
    desc: "Continuously scans stock across all locations. Detects low inventory and flags critical SKUs before you lose a sale.",
  },
  {
    iconId: "ai-orders",
    title: "PO Drafter agent",
    desc: "Analyzes sales velocity and lead times to draft purchase orders automatically. You review, it executes.",
  },
  {
    iconId: "suppliers",
    title: "Lead Scout agent",
    desc: "Finds the best suppliers for each SKU. Compares pricing, lead times, and reliability across your network.",
  },
  {
    iconId: "gdpr",
    title: "Approval Gate",
    desc: "Human-in-the-loop by design. No agent acts without your approval. Full audit trail on every decision.",
  },
  {
    iconId: "reports",
    title: "Autonomous weekly reports",
    desc: "Agents compile trend analysis, dead stock flags, and reorder recommendations. Delivered to your inbox on schedule.",
  },
  {
    iconId: "customers",
    title: "Customer DNA profiles",
    desc: "Agents build buying patterns from order history. Know which products each customer gravitates toward.",
  },
];

const TESTIMONIALS = [
  {
    quote: "Four agents replaced three manual workflows. We went from 12 stockouts a month to zero — the PO Drafter alone paid for itself in week one.",
    name: "Sarah Chen",
    role: "Head of Ops",
    company: "Lumino Candles",
  },
  {
    quote: "I used to spend hours every Monday pulling inventory reports. Now the agents compile everything overnight and I just review the highlights.",
    name: "Marcus Rivera",
    role: "Founder",
    company: "Driftwood Supply Co.",
  },
  {
    quote: "The Approval Gate is what sold us. Agents do the grunt work, but nothing ships without my sign-off. Autonomous with a safety net.",
    name: "Anya Patel",
    role: "E-commerce Manager",
    company: "Solis Activewear",
  },
];

export default function LandingPage() {
  const heroRef = useRef<HTMLDivElement>(null);
  const prefersReduced = useReducedMotion();
  const { scrollYProgress } = useScroll({
    target: heroRef,
    offset: ["start start", "end start"],
  });
  const heroY = useTransform(scrollYProgress, [0, 1], [0, prefersReduced ? 0 : 120]);
  const heroOpacity = useTransform(scrollYProgress, [0, 0.6], [1, prefersReduced ? 1 : 0]);

  const noMotion = { duration: 0 };
  const fadeIn = (delay: number, duration = 0.5) =>
    prefersReduced ? noMotion : { duration, delay, ease: [0.25, 0.1, 0.25, 1] as const };

  return (
    <div className="em">
      {/* ── Skip to content ── */}
      <a href="#main-content" className="em-skip-link">
        Skip to main content
      </a>

      {/* ── Grid lines overlay ── */}
      <div className="em-grid-lines" aria-hidden="true" />
      <div className="em-grid-line" style={{ left: '25%' }} aria-hidden="true" />
      <div className="em-grid-line" style={{ left: '75%' }} aria-hidden="true" />

      {/* ── Navigation ── */}
      <motion.nav
        className="em-nav"
        aria-label="Landing page navigation"
        initial={prefersReduced ? false : { opacity: 0, y: -16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={fadeIn(0.1)}
      >
        <div className="em-nav__inner">
          <div className="em-nav__brand">
            <BrandLogo />
            <span className="em-nav__wordmark">Inventory Intelligence</span>
          </div>
          <div className="em-nav__links">
            <a href="#features">Features</a>
            <a href="#how-it-works">How it works</a>
            <a href="#faq">FAQ</a>
          </div>
          <a href="#install" className="em-btn em-btn--primary em-btn--sm">
            Deploy agents <ArrowRight />
          </a>
        </div>
      </motion.nav>

      {/* ── Main content ── */}
      <main id="main-content">
        {/* ── Hero ── */}
        <section className="em-hero" ref={heroRef}>
          <motion.div
            className="em-hero__inner"
            style={prefersReduced ? undefined : { y: heroY, opacity: heroOpacity }}
          >
            <div className="em-hero__text">
              <motion.div
                className="em-section-label"
                initial={prefersReduced ? false : { opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={fadeIn(0.2)}
              >
                Agentic Inventory Management
              </motion.div>

              <motion.h1
                className="em-hero__title"
                initial={prefersReduced ? false : { opacity: 0, y: 32 }}
                animate={{ opacity: 1, y: 0 }}
                transition={fadeIn(0.3, 0.7)}
              >
                Four AI agents
                <br />
                manage your inventory.
                <br />
                You just approve.
              </motion.h1>

              <motion.p
                className="em-hero__subtitle"
                initial={prefersReduced ? false : { opacity: 0, y: 24 }}
                animate={{ opacity: 1, y: 0 }}
                transition={fadeIn(0.5, 0.6)}
              >
                Autonomous agents that monitor stock, draft purchase orders,
                find the best suppliers, and wait for your sign-off — so you never
                lose a sale to an empty shelf.
              </motion.p>

              <motion.div
                className="em-hero__actions"
                initial={prefersReduced ? false : { opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={fadeIn(0.7)}
              >
                <a href="#install" className="em-btn em-btn--primary">
                  Deploy your agents <ArrowRight />
                </a>
                <a href="#how-it-works" className="em-btn">
                  See how it works
                </a>
              </motion.div>

              <motion.p
                className="em-hero__note"
                initial={prefersReduced ? false : { opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={fadeIn(0.9)}
              >
                2,000+ merchants &middot; 4 autonomous agents &middot; Human-in-the-loop
              </motion.p>
            </div>

            <motion.div
              className="em-hero__visual"
              initial={prefersReduced ? false : { opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              transition={fadeIn(0.5, 0.9)}
            >
              <HeroGraphic />
            </motion.div>
          </motion.div>
        </section>

        <SectionArrows />

        {/* ── Product screenshot section ── */}
        <Reveal>
          <section className="em-section em-section--bordered">
            <div className="em-section__inner">
              <div className="em-screenshot">
                <ImagePlaceholder aspect="21/9" label="Inventory Intelligence Dashboard" />
              </div>
            </div>
          </section>
        </Reveal>

        {/* ── Features — animated cards ── */}
        <section className="em-section" id="features">
          <div className="em-section__inner">
            <Reveal>
              <div className="em-section-label">Your Agent Team</div>
              <h2 className="em-heading">
                Four agents.<br />
                One command center.
              </h2>
              <p className="em-subheading">
                Each agent has a job. Together they eliminate stockouts,
                automate reorders, and keep you in control.
              </p>
            </Reveal>

            <StaggerList className="em-fcards">
              {FEATURES.map((feature, i) => (
                <FeatureCard key={feature.iconId} feature={feature} index={i} />
              ))}
            </StaggerList>
          </div>
        </section>

        {/* ── How it works — interactive demo ── */}
        <section className="em-section em-section--bordered" id="how-it-works">
          <div className="em-section__inner">
            <Reveal>
              <div className="em-section-label">How it works</div>
              <h2 className="em-heading">
                Four steps to<br />
                agentic autopilot.
              </h2>
            </Reveal>

            <Reveal>
              <InteractiveSteps />
            </Reveal>
          </div>
        </section>

        <SectionArrows />

        {/* ── Stats — inline horizontal strip ── */}
        <section className="em-section em-section--bordered">
          <div className="em-section__inner">
            <Reveal>
              <div className="em-stats-strip" role="list">
                {[
                  { value: "2,000+", label: "Merchants" },
                  { value: "4.8M", label: "Agent decisions" },
                  { value: "$38M", label: "Revenue saved" },
                  { value: "4", label: "AI agents" },
                ].map((stat, i, arr) => (
                  <div className="em-stats-strip__item" key={stat.label} role="listitem">
                    <span className="em-stats-strip__value">{stat.value}</span>
                    <span className="em-stats-strip__label">{stat.label}</span>
                    {i < arr.length - 1 && <span className="em-stats-strip__divider" aria-hidden="true" />}
                  </div>
                ))}
              </div>
            </Reveal>
          </div>
        </section>

        {/* ── Testimonials — pull quote + cards ── */}
        <section className="em-section">
          <div className="em-section__inner">
            <Reveal>
              <div className="em-section-label">From the field</div>
              <h2 className="em-heading">
                Merchants who deployed agents.
              </h2>
            </Reveal>

            {/* Featured pull quote */}
            <Reveal>
              <figure className="em-pullquote">
                <blockquote className="em-pullquote__text">
                  &ldquo;{TESTIMONIALS[0].quote}&rdquo;
                </blockquote>
                <figcaption className="em-pullquote__cite">
                  <span className="em-pullquote__name">{TESTIMONIALS[0].name}</span>
                  <span className="em-pullquote__role">
                    {TESTIMONIALS[0].role}, {TESTIMONIALS[0].company}
                  </span>
                </figcaption>
              </figure>
            </Reveal>

            {/* Supporting testimonials */}
            <StaggerList className="em-testimonials-pair">
              {TESTIMONIALS.slice(1).map((t) => (
                <motion.figure
                  key={t.name}
                  className="em-testimonial"
                  variants={staggerChild}
                >
                  <span className="em-testimonial__mark" aria-hidden="true">&ldquo;</span>
                  <blockquote className="em-testimonial__quote">{t.quote}</blockquote>
                  <figcaption className="em-testimonial__author">
                    <div className="em-testimonial__avatar" aria-hidden="true">
                      {t.name.charAt(0)}
                    </div>
                    <div>
                      <div className="em-testimonial__name">{t.name}</div>
                      <div className="em-testimonial__role">
                        {t.role}, {t.company}
                      </div>
                    </div>
                  </figcaption>
                </motion.figure>
              ))}
            </StaggerList>
          </div>
        </section>

        {/* ── FAQ ── */}
        <section className="em-section" id="faq" aria-labelledby="faq-heading">
          <div className="em-section__inner">
            <div className="em-faq">
              <Reveal>
                <h2 id="faq-heading" className="em-heading em-faq__heading">
                  Frequently asked<br />
                  questions.
                </h2>
              </Reveal>

              <div className="em-faq__list">
                {[
                  {
                    q: "What do the four agents actually do?",
                    a: "Inventory Monitor scans stock levels continuously. PO Drafter writes purchase orders based on sales velocity. Lead Scout finds optimal suppliers. Approval Gate holds everything for your review before any action is taken.",
                  },
                  {
                    q: "Can agents take action without my approval?",
                    a: "Never. The Approval Gate agent ensures every purchase order, supplier change, and reorder decision waits for your explicit sign-off. You set the rules, agents follow them.",
                  },
                  {
                    q: "How long does setup take?",
                    a: "Under 5 minutes. Install the app, approve permissions, set your thresholds, and your agents start working immediately.",
                  },
                  {
                    q: "How do agents communicate with each other?",
                    a: "Agents pass structured messages in a chain. Monitor flags low stock, PO Drafter requests supplier data from Lead Scout, and everything routes through Approval Gate before execution.",
                  },
                  {
                    q: "Is my data secure?",
                    a: "All data is encrypted in transit and at rest. Agents operate within your tenant boundary — no merchant data is ever shared. Full GDPR compliance with automated data request handling.",
                  },
                  {
                    q: "Does it work with multiple Shopify locations?",
                    a: "Yes. Agents track inventory across all your locations and can generate location-specific purchase orders and alerts.",
                  },
                ].map((item) => (
                  <FaqItem key={item.q} q={item.q} a={item.a} />
                ))}
              </div>
            </div>
          </div>
        </section>

        <SectionArrows />

        {/* ── Final CTA ── */}
        <section className="em-section em-section--bordered" id="install">
          <div className="em-section__inner">
            <Reveal>
              <div className="em-cta">
                <h2 className="em-cta__title">
                  Deploy your agents with
                </h2>
                <div className="em-cta__brand">
                  <BrandLogo size={32} />
                  <span>Inventory Intelligence</span>
                </div>

                <a href="#install" className="em-btn em-btn--primary">
                  Deploy your agents <ArrowRight />
                </a>

                <div className="em-cta__newsletter">
                  <p className="em-cta__newsletter-title">Join the newsletter</p>
                  <p className="em-cta__newsletter-desc">
                    Product updates, releases, and notes from the team.
                  </p>
                  <form className="em-cta__newsletter-form" onSubmit={(e) => e.preventDefault()}>
                    <label htmlFor="newsletter-email" className="em-sr-only">Email address</label>
                    <input
                      id="newsletter-email"
                      type="email"
                      placeholder="you@company.com"
                      className="em-cta__input"
                      autoComplete="email"
                      required
                    />
                    <button type="submit" className="em-btn em-btn--primary em-btn--sm">Join <ArrowRight /></button>
                  </form>
                </div>
              </div>
            </Reveal>
          </div>
        </section>

        {/* ── Open Source strip ── */}
        <section className="em-section">
          <div className="em-section__inner">
            <div className="em-open-source">
              <h3 className="em-open-source__title">Proudly open source.</h3>
              <div className="em-open-source__links">
                <a href="#" className="em-btn em-btn--sm">View on GitHub <ArrowRight /></a>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* ── Footer ── */}
      <footer className="em-footer">
        <div className="em-footer__inner">
          <div className="em-footer__left">
            <p className="em-footer__copy">&copy; 2026 Inventory Intelligence</p>
            <div className="em-footer__brand">
              <span className="em-footer__brand-logo">
                <BrandLogo size={24} />
              </span>
              <span>Inventory Intelligence</span>
            </div>
          </div>
          <nav className="em-footer__right" aria-label="Footer links">
            <a href="#">About us</a>
            <a href="#">Changelog</a>
            <a href="#">Privacy Policy</a>
            <a href="#">Terms of Service</a>
          </nav>
        </div>
      </footer>
    </div>
  );
}
