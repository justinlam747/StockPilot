// StockPilot Landing — GSAP Framer-Dramatic Animations
document.addEventListener("DOMContentLoaded", function () {
  // Accessibility: respect reduced motion preference
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  // Wait for GSAP to be available (loaded with defer)
  if (typeof gsap === "undefined") {
    return;
  }

  document.body.classList.add("gsap-ready");
  gsap.registerPlugin(ScrollTrigger);

  var smooth = "power3.out";
  var expo = "expo.out";

  // ─── HERO ENTRANCE TIMELINE ───
  var hero = gsap.timeline({ defaults: { ease: expo, duration: 0.8 } });

  var heroEls = document.querySelectorAll('[data-animate="hero"]');
  heroEls.forEach(function (el, i) {
    hero.to(el, {
      opacity: 1,
      y: 0,
      duration: i === 2 ? 1 : 0.7 // headline gets longer duration
    }, 0.15 + i * 0.15);
  });

  // Dashboard slides up with a dramatic entrance
  hero.to('[data-animate="hero-dashboard"]', {
    opacity: 1,
    y: 0,
    duration: 1.1,
    ease: expo
  }, 0.4);

  // Idle floating animation on dashboard after entrance
  hero.call(function () {
    gsap.to('[data-animate="hero-dashboard"]', {
      y: -6,
      duration: 2.5,
      ease: "sine.inOut",
      yoyo: true,
      repeat: -1
    });
  }, null, 1.6);

  // ─── SOCIAL PROOF — Fade in ───
  gsap.to(".lp-proof", {
    scrollTrigger: {
      trigger: ".lp-proof",
      start: "top 88%",
      once: true
    },
    opacity: 1,
    y: 0,
    duration: 0.6,
    ease: smooth
  });

  // ─── BIG STATEMENT — Word-by-word reveal ───
  var statementEl = document.querySelector('[data-animate="words"]');
  if (statementEl) {
    var text = statementEl.textContent.trim();
    var words = text.split(/\s+/);
    statementEl.innerHTML = words.map(function (word) {
      return '<span class="word"><span class="word-inner">' + word + '</span></span>';
    }).join("");

    var wordInners = statementEl.querySelectorAll(".word-inner");

    // Set initial state
    gsap.set(wordInners, { yPercent: 110 });

    gsap.to(wordInners, {
      scrollTrigger: {
        trigger: ".lp-statement",
        start: "top 75%",
        once: true
      },
      yPercent: 0,
      duration: 0.6,
      ease: "power4.out",
      stagger: 0.08
    });
  }

  // ─── FEATURE BENTO GRID — Stagger reveal ───
  ScrollTrigger.batch('[data-animate="card"]', {
    onEnter: function (batch) {
      gsap.to(batch, {
        opacity: 1,
        y: 0,
        scale: 1,
        duration: 0.7,
        ease: smooth,
        stagger: 0.1
      });
    },
    start: "top 88%",
    once: true
  });

  // Set initial scale for cards
  gsap.set('[data-animate="card"]', { scale: 0.95 });

  // ─── FEATURES HEADER ───
  gsap.to(".lp-features__header", {
    scrollTrigger: {
      trigger: ".lp-features__header",
      start: "top 85%",
      once: true
    },
    opacity: 1,
    y: 0,
    duration: 0.6,
    ease: smooth
  });

  // ─── HOW IT WORKS — Sequential step reveal ───
  var stepsHeader = document.querySelector(".lp-steps__header");
  if (stepsHeader) {
    gsap.to(stepsHeader, {
      scrollTrigger: {
        trigger: stepsHeader,
        start: "top 85%",
        once: true
      },
      opacity: 1,
      y: 0,
      duration: 0.6,
      ease: smooth
    });
  }

  var stepsTl = gsap.timeline({
    scrollTrigger: {
      trigger: ".lp-steps__row",
      start: "top 80%",
      once: true
    },
    defaults: { ease: smooth }
  });

  document.querySelectorAll('[data-animate="step"]').forEach(function (el, i) {
    stepsTl.to(el, { opacity: 1, y: 0, duration: 0.6 }, i * 0.25);
    // Draw connector after each step (except last)
    var connectors = document.querySelectorAll('[data-animate="connector"]');
    if (connectors[i]) {
      stepsTl.to(connectors[i], { scaleX: 1, duration: 0.4 }, i * 0.25 + 0.3);
    }
  });

  // ─── DASHBOARD PREVIEW — Scale + parallax ───
  var previewEl = document.querySelector('[data-animate="preview"]');
  if (previewEl) {
    gsap.set(previewEl, { scale: 0.92 });

    gsap.to(previewEl, {
      scrollTrigger: {
        trigger: ".lp-preview",
        start: "top 80%",
        once: true
      },
      opacity: 1,
      y: 0,
      scale: 1,
      duration: 0.9,
      ease: smooth
    });
  }

  // ─── TESTIMONIAL — Fade ───
  gsap.to(".lp-testimonial", {
    scrollTrigger: {
      trigger: ".lp-testimonial",
      start: "top 80%",
      once: true
    },
    opacity: 1,
    y: 0,
    duration: 0.7,
    ease: smooth
  });

  // ─── CTA FOOTER — Stagger ───
  var ctaInner = document.querySelector(".lp-cta__inner");
  if (ctaInner) {
    gsap.to(ctaInner, {
      scrollTrigger: {
        trigger: ".lp-cta",
        start: "top 80%",
        once: true
      },
      opacity: 1,
      y: 0,
      duration: 0.7,
      ease: smooth
    });
  }
});
