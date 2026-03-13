import { useRef } from "react";
import {
  motion,
  useScroll,
  useTransform,
  useReducedMotion,
} from "framer-motion";
import "../styles/stockpilot.css";

/* ── Arrow icon ── */
function ArrowRight() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true" style={{ marginLeft: 6 }}>
      <path d="M3 8h10M9 4l4 4-4 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

/* ── Sticky slide-up frames data ── */
const FRAMES = [
  {
    label: "Your Agent Team",
    title: "Four agents.\nOne command center.",
    items: [
      { num: "01", name: "Inventory Monitor", desc: "Scans stock across all locations. Flags critical SKUs before you lose a sale." },
      { num: "02", name: "PO Drafter", desc: "Analyzes velocity and lead times. Drafts purchase orders automatically." },
      { num: "03", name: "Lead Scout", desc: "Finds the best suppliers. Compares pricing, lead times, and reliability." },
      { num: "04", name: "Approval Gate", desc: "Human-in-the-loop. No agent acts without your sign-off." },
    ],
  },
  {
    label: "How it works",
    title: "Connect. Configure.\nLet agents fly.",
    steps: [
      { n: "1", name: "Connect your store", desc: "Install and sync your Shopify products in under 60 seconds." },
      { n: "2", name: "Set your rules", desc: "Configure thresholds, alerts, and reorder preferences." },
      { n: "3", name: "Agents take over", desc: "Four AI agents start monitoring and managing your inventory." },
      { n: "4", name: "You review & approve", desc: "Every PO, every decision waits for your sign-off." },
    ],
  },
  {
    label: "Ready?",
    title: "Ready for takeoff?",
    cta: true,
  },
] as const;

export default function StockPilotLanding() {
  const prefersReduced = useReducedMotion();
  const noReduce = !prefersReduced;

  /* ── Hero scroll ── */
  const heroRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress: heroProgress } = useScroll({
    target: heroRef,
    offset: ["start start", "end start"],
  });

  // Phase 1 (0 → 0.5): image scales from 72% rounded card → 100% fullscreen
  // Phase 2 (0.5 → 0.8): image stays full, content fades
  // Phase 3 (0.8 → 1.0): everything fades out
  const imgScale = useTransform(heroProgress, [0, 0.5], [0.72, noReduce ? 1.0 : 0.72]);
  const imgRadius = useTransform(heroProgress, [0, 0.5], [28, noReduce ? 0 : 28]);
  const heroFade = useTransform(heroProgress, [0.6, 0.85], [1, noReduce ? 0 : 1]);

  /* ── Sticky frames scroll ── */
  const framesRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress: framesProgress } = useScroll({
    target: framesRef,
    offset: ["start start", "end end"],
  });

  // Each frame gets a slice of the scroll progress
  const frameCount = FRAMES.length;
  const getFrameY = (index: number) => {
    const start = index / frameCount;
    const end = (index + 0.3) / frameCount;
    // eslint-disable-next-line react-hooks/rules-of-hooks
    return useTransform(framesProgress, [start, end], [noReduce ? 100 : 0, 0]);
  };

  const getFrameOpacity = (index: number) => {
    const fadeInStart = index / frameCount;
    const fadeInEnd = (index + 0.2) / frameCount;
    const fadeOutStart = (index + 0.7) / frameCount;
    const fadeOutEnd = (index + 0.95) / frameCount;
    const isLast = index === frameCount - 1;
    // eslint-disable-next-line react-hooks/rules-of-hooks
    return useTransform(
      framesProgress,
      isLast
        ? [fadeInStart, fadeInEnd]
        : [fadeInStart, fadeInEnd, fadeOutStart, fadeOutEnd],
      isLast
        ? [noReduce ? 0 : 1, 1]
        : [noReduce ? 0 : 1, 1, 1, noReduce ? 0 : 1]
    );
  };

  const noMotion = { duration: 0 };
  const fadeIn = (delay: number, duration = 0.6) =>
    prefersReduced ? noMotion : { duration, delay, ease: [0.25, 0.1, 0.25, 1] as const };

  return (
    <div className="sp">
      <a href="#sp-main" className="sp-skip">Skip to main content</a>

      {/* ── Dotted grid overlay ── */}
      <div className="sp-grid" aria-hidden="true">
        <div className="sp-grid__line sp-grid__line--1" />
        <div className="sp-grid__line sp-grid__line--2" />
        <div className="sp-grid__line sp-grid__line--3" />
        <div className="sp-grid__line sp-grid__line--4" />
        <div className="sp-grid__hline sp-grid__hline--1" />
        <div className="sp-grid__hline sp-grid__hline--2" />
        <div className="sp-grid__hline sp-grid__hline--3" />
      </div>

      {/* ── Nav ── */}
      <motion.nav
        className="sp-nav"
        aria-label="Stock Pilot navigation"
        initial={prefersReduced ? false : { opacity: 0, y: -12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={fadeIn(0.1)}
      >
        <div className="sp-nav__inner">
          <div className="sp-nav__brand">
            <svg width="22" height="22" viewBox="0 0 28 28" fill="none" aria-hidden="true">
              <rect x="2" y="2" width="24" height="24" rx="6" stroke="currentColor" strokeWidth="1.5" />
              <rect x="7" y="14" width="4" height="8" rx="1" fill="currentColor" />
              <rect x="12" y="10" width="4" height="12" rx="1" fill="var(--sp-blue-muted)" />
              <rect x="17" y="6" width="4" height="16" rx="1" fill="currentColor" />
            </svg>
            <span className="sp-nav__wordmark">Stock Pilot</span>
          </div>
          <div className="sp-nav__links">
            <a href="#sp-features">Features</a>
            <a href="#sp-how">How it works</a>
          </div>
          <a href="#sp-cta" className="sp-btn sp-btn--primary sp-btn--sm">
            Get started <ArrowRight />
          </a>
        </div>
      </motion.nav>

      {/* ══════════════════════════════════════
         HERO — image expands then fades out
         ══════════════════════════════════════ */}
      <section className="sp-hero" ref={heroRef} id="sp-main">
        {/* Sticky viewport — image + text pinned here */}
        <div className="sp-hero__sticky">
          {/* Expanding image */}
          <motion.div
            className="sp-hero__bg"
            style={
              prefersReduced
                ? undefined
                : { scale: imgScale, borderRadius: imgRadius, opacity: heroFade }
            }
          >
            <img src="/images/hero-bg.jpg" alt="" className="sp-hero__bg-img" />
            <div className="sp-hero__bg-overlay" />
          </motion.div>

          {/* Text overlay — fades with the hero */}
          <motion.div
            className="sp-hero__content"
            style={prefersReduced ? undefined : { opacity: heroFade }}
          >
            <motion.div
              className="sp-pill"
              initial={prefersReduced ? false : { opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={fadeIn(0.2)}
            >
              <img src="/images/shopify-bag.png" alt="" className="sp-pill__icon" />
              <span>Built for Shopify</span>
            </motion.div>

            <motion.h1
              className="sp-hero__title"
              initial={prefersReduced ? false : { opacity: 0, y: 28 }}
              animate={{ opacity: 1, y: 0 }}
              transition={fadeIn(0.3, 0.7)}
            >
              $tockPilot
            </motion.h1>

            <motion.p
              className="sp-hero__sub"
              initial={prefersReduced ? false : { opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={fadeIn(0.5)}
            >
              Four AI agents monitor stock, draft purchase orders,
              find suppliers, and wait for your sign-off — so you
              never lose a sale to an empty shelf.
            </motion.p>

            <motion.div
              className="sp-hero__actions"
              initial={prefersReduced ? false : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={fadeIn(0.65)}
            >
              <a href="#sp-cta" className="sp-btn sp-btn--hero">
                Deploy your agents <ArrowRight />
              </a>
              <a href="#sp-how" className="sp-btn sp-btn--hero-secondary">
                See how it works
              </a>
            </motion.div>

            <motion.p
              className="sp-hero__proof"
              initial={prefersReduced ? false : { opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={fadeIn(0.85)}
            >
              2,000+ merchants &middot; 4 AI agents &middot; Human-in-the-loop
            </motion.p>
          </motion.div>
        </div>
      </section>

      {/* ══════════════════════════════════════
         STICKY FRAMES — panels slide up
         ══════════════════════════════════════ */}
      <section className="sp-frames" ref={framesRef} id="sp-features">
        <div className="sp-frames__sticky">
          {FRAMES.map((frame, i) => {
            const y = getFrameY(i);
            const opacity = getFrameOpacity(i);

            return (
              <motion.div
                key={i}
                className="sp-frame"
                style={{
                  y: prefersReduced ? 0 : y,
                  opacity: prefersReduced ? 1 : opacity,
                  zIndex: i + 1,
                }}
              >
                <div className="sp-frame__inner">
                  <span className="sp-label">{frame.label}</span>
                  <h2 className="sp-heading" style={{ whiteSpace: "pre-line" }}>
                    {frame.title}
                  </h2>

                  {"items" in frame && (
                    <div className="sp-features">
                      {frame.items.map((f) => (
                        <div key={f.num} className="sp-feature">
                          <span className="sp-feature__num">{f.num}</span>
                          <h3 className="sp-feature__title">{f.name}</h3>
                          <p className="sp-feature__desc">{f.desc}</p>
                        </div>
                      ))}
                    </div>
                  )}

                  {"steps" in frame && (
                    <div className="sp-steps">
                      {frame.steps.map((s, si) => (
                        <div key={s.n} className="sp-step">
                          <div className="sp-step__num">{s.n}</div>
                          <div className="sp-step__content">
                            <h3 className="sp-step__title">{s.name}</h3>
                            <p className="sp-step__desc">{s.desc}</p>
                          </div>
                          {si < frame.steps.length - 1 && (
                            <div className="sp-step__connector" aria-hidden="true" />
                          )}
                        </div>
                      ))}
                    </div>
                  )}

                  {"cta" in frame && (
                    <div className="sp-cta">
                      <img src="/images/plane.png" alt="" className="sp-cta__plane" />
                      <p className="sp-cta__sub">
                        Deploy your agents and put your inventory on autopilot.
                      </p>
                      <a href="#" className="sp-btn sp-btn--primary">
                        Get started free <ArrowRight />
                      </a>
                    </div>
                  )}
                </div>
              </motion.div>
            );
          })}
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="sp-footer">
        <div className="sp-footer__inner">
          <p>&copy; 2026 Stock Pilot</p>
          <nav aria-label="Footer links">
            <a href="#">Privacy</a>
            <a href="#">Terms</a>
            <a href="#">Changelog</a>
          </nav>
        </div>
      </footer>
    </div>
  );
}
