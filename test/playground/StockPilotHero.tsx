/**
 * StockPilot Hero — Isometric 3D e-commerce scene
 * CSS-only isometric objects, parallax mouse tracking, individual hover reactions.
 * Bright colors, glow, grain texture, drop shadows.
 */
import { useState, useRef, useCallback, useEffect } from "react";

/* ── Mouse position hook ── */
function useMouseParallax() {
  const [pos, setPos] = useState({ x: 0.5, y: 0.5 });
  const onMove = useCallback((e: MouseEvent) => {
    setPos({ x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight });
  }, []);
  useEffect(() => {
    window.addEventListener("mousemove", onMove);
    return () => window.removeEventListener("mousemove", onMove);
  }, [onMove]);
  return pos;
}

/* ── Isometric face component ── */
function IsoBox({
  width,
  height,
  depth,
  color,
  glow,
  x,
  y,
  z,
  label,
  children,
}: {
  width: number;
  height: number;
  depth: number;
  color: string;
  glow: string;
  x: number;
  y: number;
  z: number;
  label?: string;
  children?: React.ReactNode;
}) {
  const [hovered, setHovered] = useState(false);

  // Darken/lighten helpers
  const topColor = `color-mix(in srgb, ${color} 80%, white)`;
  const rightColor = color;
  const leftColor = `color-mix(in srgb, ${color} 70%, black)`;

  return (
    <div
      className="iso-object"
      data-layer={z}
      style={{
        position: "absolute",
        left: `${x}%`,
        top: `${y}%`,
        zIndex: z,
        transform: `translate(-50%, -50%) scale(${hovered ? 1.12 : 1})`,
        transition: "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), filter 0.3s ease",
        cursor: "pointer",
        filter: hovered
          ? `drop-shadow(0 0 30px ${glow}) drop-shadow(0 20px 40px rgba(0,0,0,0.5))`
          : `drop-shadow(0 0 15px ${glow}) drop-shadow(0 12px 25px rgba(0,0,0,0.4))`,
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {/* Isometric container */}
      <div
        style={{
          transformStyle: "preserve-3d",
          transform: "rotateX(55deg) rotateZ(-45deg)",
          position: "relative",
          width: `${width}px`,
          height: `${depth}px`,
        }}
      >
        {/* Top face */}
        <div
          style={{
            position: "absolute",
            width: `${width}px`,
            height: `${depth}px`,
            background: topColor,
            transform: `translateZ(${height}px)`,
            borderRadius: "3px",
          }}
        >
          {children}
        </div>

        {/* Front face */}
        <div
          style={{
            position: "absolute",
            width: `${width}px`,
            height: `${height}px`,
            background: rightColor,
            transformOrigin: "bottom",
            transform: `rotateX(-90deg) translateZ(${depth}px)`,
            borderRadius: "0 0 3px 3px",
          }}
        />

        {/* Right face */}
        <div
          style={{
            position: "absolute",
            width: `${depth}px`,
            height: `${height}px`,
            background: leftColor,
            transformOrigin: "bottom right",
            transform: `rotateX(-90deg) rotateY(90deg) translateZ(${depth}px)`,
            borderRadius: "0 0 3px 3px",
          }}
        />
      </div>

      {/* Label on hover */}
      {label && (
        <div
          style={{
            position: "absolute",
            bottom: "-32px",
            left: "50%",
            transform: "translateX(-50%)",
            fontSize: "11px",
            fontWeight: 600,
            color: "#fff",
            background: "rgba(0,0,0,0.7)",
            padding: "4px 10px",
            borderRadius: "6px",
            whiteSpace: "nowrap",
            opacity: hovered ? 1 : 0,
            transition: "opacity 0.3s ease",
            backdropFilter: "blur(8px)",
            letterSpacing: "0.5px",
          }}
        >
          {label}
        </div>
      )}
    </div>
  );
}

/* ── Flat panel (product card, clipboard) ── */
function IsoPanel({
  width,
  depth,
  color,
  glow,
  x,
  y,
  z,
  label,
  children,
}: {
  width: number;
  depth: number;
  color: string;
  glow: string;
  x: number;
  y: number;
  z: number;
  label?: string;
  children?: React.ReactNode;
}) {
  const [hovered, setHovered] = useState(false);

  return (
    <div
      className="iso-object"
      data-layer={z}
      style={{
        position: "absolute",
        left: `${x}%`,
        top: `${y}%`,
        zIndex: z,
        transform: `translate(-50%, -50%) scale(${hovered ? 1.12 : 1})`,
        transition: "transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), filter 0.3s ease",
        cursor: "pointer",
        filter: hovered
          ? `drop-shadow(0 0 25px ${glow}) drop-shadow(0 16px 30px rgba(0,0,0,0.5))`
          : `drop-shadow(0 0 10px ${glow}) drop-shadow(0 10px 20px rgba(0,0,0,0.35))`,
      }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <div
        style={{
          transform: "rotateX(55deg) rotateZ(-45deg)",
          width: `${width}px`,
          height: `${depth}px`,
          background: color,
          borderRadius: "6px",
          padding: "12px",
          position: "relative",
        }}
      >
        {children}
      </div>
      {label && (
        <div
          style={{
            position: "absolute",
            bottom: "-32px",
            left: "50%",
            transform: "translateX(-50%)",
            fontSize: "11px",
            fontWeight: 600,
            color: "#fff",
            background: "rgba(0,0,0,0.7)",
            padding: "4px 10px",
            borderRadius: "6px",
            whiteSpace: "nowrap",
            opacity: hovered ? 1 : 0,
            transition: "opacity 0.3s ease",
            backdropFilter: "blur(8px)",
            letterSpacing: "0.5px",
          }}
        >
          {label}
        </div>
      )}
    </div>
  );
}

/* ── Signal pulse along AI thread ── */
function SignalPulse({ x1, y1, x2, y2, delay = 0 }: { x1: number; y1: number; x2: number; y2: number; delay?: number }) {
  return (
    <line
      x1={`${x1}%`}
      y1={`${y1}%`}
      x2={`${x2}%`}
      y2={`${y2}%`}
      stroke="rgba(78,205,196,0.4)"
      strokeWidth="1.5"
      strokeDasharray="6 8"
      style={{
        animation: `dashFlow 3s linear ${delay}s infinite`,
      }}
    />
  );
}

/* ── Main Hero ── */
export default function StockPilotHero() {
  const mouse = useMouseParallax();
  const sceneRef = useRef<HTMLDivElement>(null);

  // Parallax offset calculation
  const px = (layer: number) => (mouse.x - 0.5) * layer * 30;
  const py = (layer: number) => (mouse.y - 0.5) * layer * 20;

  return (
    <section
      style={{
        position: "relative",
        width: "100vw",
        height: "100vh",
        background: "#0F0F12",
        overflow: "hidden",
        fontFamily: "'Satoshi', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      }}
    >
      {/* Grain overlay */}
      <svg style={{ position: "absolute", width: 0, height: 0 }}>
        <defs>
          <filter id="grain">
            <feTurbulence type="fractalNoise" baseFrequency="0.65" numOctaves="3" stitchTiles="stitch" />
            <feColorMatrix type="saturate" values="0" />
          </filter>
        </defs>
      </svg>
      <div
        style={{
          position: "absolute",
          inset: 0,
          opacity: 0.04,
          filter: "url(#grain)",
          zIndex: 50,
          pointerEvents: "none",
        }}
      />

      {/* AI Thread Lines */}
      <svg
        style={{
          position: "absolute",
          inset: 0,
          width: "100%",
          height: "100%",
          zIndex: 5,
          pointerEvents: "none",
        }}
      >
        <style>{`
          @keyframes dashFlow {
            to { stroke-dashoffset: -42; }
          }
        `}</style>
        <SignalPulse x1={35} y1={30} x2={58} y2={22} delay={0} />
        <SignalPulse x1={58} y1={22} x2={78} y2={38} delay={0.5} />
        <SignalPulse x1={45} y1={55} x2={68} y2={48} delay={1} />
        <SignalPulse x1={68} y1={48} x2={85} y2={60} delay={1.5} />
        <SignalPulse x1={30} y1={50} x2={50} y2={65} delay={0.8} />

        {/* Glowing dots at intersections */}
        {[
          { cx: 35, cy: 30 },
          { cx: 58, cy: 22 },
          { cx: 78, cy: 38 },
          { cx: 45, cy: 55 },
          { cx: 68, cy: 48 },
          { cx: 85, cy: 60 },
        ].map((dot, i) => (
          <circle
            key={i}
            cx={`${dot.cx}%`}
            cy={`${dot.cy}%`}
            r="3"
            fill="#4ECDC4"
            opacity="0.6"
          >
            <animate
              attributeName="opacity"
              values="0.3;0.8;0.3"
              dur="2s"
              begin={`${i * 0.4}s`}
              repeatCount="indefinite"
            />
          </circle>
        ))}
      </svg>

      {/* 3D Scene with parallax layers */}
      <div
        ref={sceneRef}
        style={{
          position: "absolute",
          inset: 0,
          perspective: "1200px",
          zIndex: 10,
        }}
      >
        {/* Layer 1 — far background objects */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            transform: `translate(${px(1)}px, ${py(1)}px)`,
            transition: "transform 0.15s ease-out",
          }}
        >
          {/* Price tag */}
          <IsoBox
            width={50} height={40} depth={50}
            color="#A78BFA" glow="rgba(167,139,250,0.4)"
            x={25} y={20} z={1}
            label="Smart Pricing"
          >
            <div style={{ color: "#fff", fontSize: "18px", fontWeight: 800, textAlign: "center", paddingTop: "10px" }}>$</div>
          </IsoBox>

          {/* Small box */}
          <IsoBox
            width={45} height={30} depth={40}
            color="#D4A574" glow="rgba(212,165,116,0.3)"
            x={80} y={65} z={1}
            label="Shipment"
          />
        </div>

        {/* Layer 2 — mid-ground objects */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            transform: `translate(${px(2)}px, ${py(2)}px)`,
            transition: "transform 0.15s ease-out",
          }}
        >
          {/* Shopping bag */}
          <IsoBox
            width={70} height={90} depth={60}
            color="#FF6B6B" glow="rgba(255,107,107,0.45)"
            x={58} y={22} z={2}
            label="Storefront"
          >
            {/* Handle */}
            <div style={{
              width: "24px", height: "12px",
              border: "3px solid rgba(255,255,255,0.5)",
              borderBottom: "none",
              borderRadius: "12px 12px 0 0",
              margin: "6px auto 0",
            }} />
          </IsoBox>

          {/* Warehouse shelf */}
          <IsoBox
            width={100} height={70} depth={40}
            color="#64748B" glow="rgba(100,116,139,0.35)"
            x={78} y={38} z={2}
            label="Warehouse"
          >
            {/* Shelf items */}
            <div style={{ display: "flex", gap: "4px", padding: "6px", flexWrap: "wrap" }}>
              {["#FF6B6B", "#4ECDC4", "#FFB347", "#A78BFA"].map((c, i) => (
                <div key={i} style={{ width: "14px", height: "10px", background: c, borderRadius: "2px" }} />
              ))}
            </div>
          </IsoBox>

          {/* Inventory meter */}
          <IsoPanel
            width={55} depth={100}
            color="rgba(255,255,255,0.08)"
            glow="rgba(52,211,153,0.3)"
            x={45} y={55} z={2}
            label="Stock Level"
          >
            <div style={{
              width: "16px", height: "70px",
              background: "rgba(255,255,255,0.1)",
              borderRadius: "8px",
              margin: "0 auto",
              position: "relative",
              overflow: "hidden",
            }}>
              <div style={{
                position: "absolute",
                bottom: 0,
                width: "100%",
                height: "65%",
                background: "linear-gradient(to top, #FF6B6B, #FFB347, #34D399)",
                borderRadius: "8px",
              }} />
            </div>
          </IsoPanel>
        </div>

        {/* Layer 3 — foreground objects */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            transform: `translate(${px(3)}px, ${py(3)}px)`,
            transition: "transform 0.15s ease-out",
          }}
        >
          {/* Shopping cart */}
          <IsoBox
            width={80} height={55} depth={60}
            color="#4ECDC4" glow="rgba(78,205,196,0.45)"
            x={68} y={48} z={3}
            label="Orders"
          >
            <div style={{ display: "flex", gap: "3px", padding: "6px" }}>
              {[1, 2, 3].map((i) => (
                <div key={i} style={{ width: "12px", height: "12px", background: "rgba(255,255,255,0.3)", borderRadius: "2px" }} />
              ))}
            </div>
          </IsoBox>

          {/* Product card */}
          <IsoPanel
            width={90} depth={110}
            color="#FFB347" glow="rgba(255,179,71,0.45)"
            x={35} y={30} z={3}
            label="Product Intel"
          >
            {/* Mock product image */}
            <div style={{
              width: "100%",
              height: "50px",
              background: "rgba(255,255,255,0.2)",
              borderRadius: "4px",
              marginBottom: "6px",
            }} />
            {/* Price */}
            <div style={{ color: "rgba(0,0,0,0.6)", fontSize: "10px", fontWeight: 700 }}>$49.99</div>
            <div style={{
              width: "60%", height: "4px",
              background: "rgba(0,0,0,0.15)",
              borderRadius: "2px",
              marginTop: "4px",
            }} />
          </IsoPanel>

          {/* Clipboard checklist */}
          <IsoPanel
            width={70} depth={90}
            color="#F1F5F9" glow="rgba(241,245,249,0.2)"
            x={85} y={60} z={3}
            label="Reorder Checklist"
          >
            {[1, 2, 3, 4].map((i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: "6px", marginBottom: "5px" }}>
                <div style={{
                  width: "10px", height: "10px",
                  borderRadius: "2px",
                  background: i <= 2 ? "#34D399" : "rgba(0,0,0,0.1)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: "7px", color: "#fff",
                }}>
                  {i <= 2 ? "✓" : ""}
                </div>
                <div style={{ height: "4px", flex: 1, background: "rgba(0,0,0,0.1)", borderRadius: "2px" }} />
              </div>
            ))}
          </IsoPanel>

          {/* Stacked boxes */}
          <div
            style={{
              position: "absolute",
              left: "30%",
              top: "60%",
              zIndex: 3,
            }}
          >
            <IsoBox
              width={55} height={35} depth={45}
              color="#D4A574" glow="rgba(212,165,116,0.35)"
              x={0} y={0} z={3}
              label="Inventory"
            >
              {/* Tape */}
              <div style={{
                width: "100%", height: "6px",
                background: "rgba(255,255,255,0.3)",
                position: "absolute",
                top: "50%",
                transform: "translateY(-50%)",
              }} />
            </IsoBox>
          </div>
        </div>
      </div>

      {/* Text overlay — lower left */}
      <div
        style={{
          position: "absolute",
          bottom: "10%",
          left: "5%",
          zIndex: 20,
          maxWidth: "520px",
        }}
      >
        <h1
          style={{
            fontSize: "clamp(40px, 6vw, 72px)",
            fontWeight: 900,
            color: "#FFFFFF",
            lineHeight: 1.05,
            letterSpacing: "-0.03em",
            margin: 0,
          }}
        >
          Stock
          <span style={{ color: "#4ECDC4" }}>pilot</span>
        </h1>
        <p
          style={{
            fontSize: "clamp(16px, 1.8vw, 20px)",
            color: "rgba(255,255,255,0.55)",
            marginTop: "16px",
            lineHeight: 1.5,
            maxWidth: "440px",
          }}
        >
          Agentic supply-chain intelligence for Shopify merchants.
          AI agents that watch, score, and reorder — so you never think about inventory again.
        </p>
        <div style={{ display: "flex", gap: "12px", marginTop: "28px" }}>
          <button
            style={{
              padding: "12px 28px",
              fontSize: "15px",
              fontWeight: 600,
              color: "#0F0F12",
              background: "#4ECDC4",
              border: "none",
              borderRadius: "8px",
              cursor: "pointer",
              letterSpacing: "0.3px",
              boxShadow: "0 0 20px rgba(78,205,196,0.4), 0 4px 12px rgba(0,0,0,0.3)",
              transition: "transform 0.2s ease, box-shadow 0.2s ease",
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = "translateY(-2px)";
              e.currentTarget.style.boxShadow = "0 0 30px rgba(78,205,196,0.6), 0 6px 16px rgba(0,0,0,0.4)";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = "translateY(0)";
              e.currentTarget.style.boxShadow = "0 0 20px rgba(78,205,196,0.4), 0 4px 12px rgba(0,0,0,0.3)";
            }}
          >
            Get Early Access
          </button>
          <button
            style={{
              padding: "12px 28px",
              fontSize: "15px",
              fontWeight: 600,
              color: "rgba(255,255,255,0.7)",
              background: "transparent",
              border: "1px solid rgba(255,255,255,0.2)",
              borderRadius: "8px",
              cursor: "pointer",
              letterSpacing: "0.3px",
              transition: "border-color 0.2s ease, color 0.2s ease",
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = "rgba(255,255,255,0.5)";
              e.currentTarget.style.color = "#fff";
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = "rgba(255,255,255,0.2)";
              e.currentTarget.style.color = "rgba(255,255,255,0.7)";
            }}
          >
            Learn More
          </button>
        </div>
      </div>

      {/* Subtle radial gradient for depth */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(ellipse 80% 60% at 60% 40%, rgba(78,205,196,0.06) 0%, transparent 70%)",
          zIndex: 2,
          pointerEvents: "none",
        }}
      />

      {/* Bottom vignette for text readability */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: "50%",
          background: "linear-gradient(to top, rgba(15,15,18,0.9) 0%, transparent 100%)",
          zIndex: 15,
          pointerEvents: "none",
        }}
      />
    </section>
  );
}
