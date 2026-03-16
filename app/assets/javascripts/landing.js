// StockPilot Landing — Premium GSAP Animations
document.addEventListener("DOMContentLoaded", function () {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches || typeof gsap === "undefined") {
    return;
  }

  document.body.classList.add("gsap-ready");
  gsap.registerPlugin(ScrollTrigger);

  var quint = "power4.out";
  var smooth = "power3.out";

  // ─── SPLIT TEXT UTILITY ───
  // Wraps each word in a span for word-by-word animation
  function splitWords(el) {
    var html = el.innerHTML;
    // Preserve <br> tags
    var parts = html.split(/(<br\s*\/?>)/gi);
    var result = "";
    for (var i = 0; i < parts.length; i++) {
      if (/^<br/i.test(parts[i])) {
        result += parts[i];
      } else {
        var words = parts[i].split(/(\s+)/);
        for (var j = 0; j < words.length; j++) {
          if (/^\s+$/.test(words[j]) || words[j] === "") {
            result += words[j];
          } else {
            result += '<span class="sp-word"><span class="sp-word__inner">' + words[j] + "</span></span>";
          }
        }
      }
    }
    el.innerHTML = result;
    return el.querySelectorAll(".sp-word__inner");
  }

  // ─── HERO ENTRANCE ───
  var hero = gsap.timeline({ defaults: { ease: quint } });

  // Nav
  hero.to(".sp-nav", { opacity: 1, y: 0, duration: 0.8 }, 0.1);

  // Hero title — word-by-word reveal
  var titleEl = document.querySelector(".sp-hero__title");
  if (titleEl) {
    var titleWords = splitWords(titleEl);
    hero.to(titleWords, {
      y: 0, opacity: 1,
      duration: 0.7,
      stagger: 0.04,
      ease: "power3.out"
    }, 0.3);
  }

  // Subtitle
  hero.to(".sp-hero__sub", { opacity: 1, y: 0, duration: 0.9, ease: smooth }, 0.8);

  // CTA buttons
  hero.to(".sp-hero__actions", { opacity: 1, y: 0, duration: 0.8 }, 1.0);

  // Dashboard mockup — dramatic entrance with 3D perspective lift
  hero.to(".sp-hero__screenshot", {
    opacity: 1, y: 0, scale: 1, rotateX: 2,
    duration: 1.6, ease: "expo.out"
  }, 0.7);

  // Mockup internals cascade after landing
  hero.to(".sp-mock__sidebar", { opacity: 1, x: 0, duration: 0.6, ease: smooth }, 1.6);
  hero.to(".sp-mock__page-header", { opacity: 1, y: 0, duration: 0.5, ease: smooth }, 1.7);
  hero.to(".sp-mock__kpi", {
    opacity: 1, y: 0, scale: 1,
    duration: 0.5, stagger: 0.08, ease: smooth
  }, 1.8);
  hero.to(".sp-mock__card", {
    opacity: 1, y: 0,
    duration: 0.6, stagger: 0.12, ease: smooth
  }, 2.0);

  // ─── KPI COUNTER ANIMATION ───
  document.querySelectorAll(".sp-mock__kpi-val").forEach(function (el) {
    var text = el.textContent.trim();
    var num = parseInt(text.replace(/,/g, ""), 10);
    if (isNaN(num) || num === 0) return;
    var hasComma = text.indexOf(",") !== -1;
    var obj = { val: 0 };
    gsap.to(obj, {
      val: num, duration: 2, delay: 2.2, ease: "power2.out",
      onUpdate: function () {
        var v = Math.round(obj.val);
        el.textContent = hasComma ? v.toLocaleString() : v.toString();
      }
    });
  });

  // ─── HERO PARALLAX — Mockup drifts on scroll ───
  gsap.to(".sp-hero__screenshot", {
    yPercent: 6, scale: 0.96,
    ease: "none",
    scrollTrigger: {
      trigger: ".sp-hero",
      start: "top top",
      end: "bottom top",
      scrub: true
    }
  });

  // ─── NAV SHRINK ON SCROLL ───
  ScrollTrigger.create({
    start: "top -80",
    onUpdate: function (self) {
      if (self.direction === 1) {
        gsap.to(".sp-nav__inner", { height: 52, duration: 0.3, ease: smooth });
      } else {
        gsap.to(".sp-nav__inner", { height: 64, duration: 0.3, ease: smooth });
      }
    }
  });

  // ─── SECTION HEADERS — Word split reveal on scroll ───
  document.querySelectorAll(".sp-section__title").forEach(function (el) {
    var words = splitWords(el);
    gsap.to(words, {
      y: 0, opacity: 1,
      duration: 0.6, stagger: 0.03, ease: quint,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });

  document.querySelectorAll(".sp-section__sub").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 88%", once: true }
    });
  });

  // ─── FEATURE CARDS — Staggered rise with scale ───
  ScrollTrigger.batch(".sp-feature-card", {
    onEnter: function (batch) {
      gsap.to(batch, {
        opacity: 1, y: 0, scale: 1,
        duration: 0.9, ease: quint, stagger: 0.15
      });
    },
    start: "top 88%",
    once: true
  });

  // Feature card visual — subtle inner content animation
  document.querySelectorAll(".sp-feature-card").forEach(function (card) {
    var visual = card.querySelector(".sp-feature-card__visual");
    if (!visual) return;
    // Animate inner content on scroll into view
    var items = visual.querySelectorAll(".sp-agent-preview__item, .sp-flow-step, .sp-shield");
    if (items.length) {
      gsap.to(items, {
        opacity: 1, y: 0, x: 0,
        duration: 0.5, stagger: 0.08, ease: smooth,
        scrollTrigger: { trigger: card, start: "top 80%", once: true },
        delay: 0.4
      });
    }
  });

  // ─── LIVE DOT PULSE — GSAP-powered instead of CSS ───
  var liveDots = document.querySelectorAll(".sp-live-dot");
  liveDots.forEach(function (dot) {
    gsap.to(dot, {
      scale: 1.6, opacity: 0.3,
      duration: 1, ease: "power1.inOut",
      repeat: -1, yoyo: true
    });
  });

  // ─── PROGRESS BAR FILL ANIMATION ───
  var progressBars = document.querySelectorAll(".sp-agent-preview__progress");
  progressBars.forEach(function (bar) {
    gsap.fromTo(bar, { "--progress-width": "0%" }, {
      "--progress-width": "67%", duration: 1.5, ease: "power2.out",
      scrollTrigger: { trigger: bar, start: "top 90%", once: true },
      delay: 0.8
    });
  });

  // ─── FLOW STEPS — Sequential check animation ───
  var flowSteps = document.querySelectorAll(".sp-flow-step");
  if (flowSteps.length) {
    var flowTl = gsap.timeline({
      scrollTrigger: {
        trigger: ".sp-agent-preview--flow",
        start: "top 80%",
        once: true
      }
    });
    flowSteps.forEach(function (step, i) {
      var check = step.querySelector(".sp-flow-check svg path, .sp-flow-dot");
      flowTl.to(step, { opacity: 1, y: 0, x: 0, duration: 0.4, ease: smooth }, i * 0.18 + 0.4);
      if (check) {
        flowTl.to(check, { scale: 1, opacity: 1, duration: 0.3, ease: "back.out(2)" }, i * 0.18 + 0.55);
      }
    });
  }

  // ─── SHIELD SVG DRAW ───
  var shieldPath = document.querySelector(".sp-shield svg path:first-child");
  var shieldCheck = document.querySelector(".sp-shield svg path:last-child");
  if (shieldPath) {
    var pathLen = shieldPath.getTotalLength ? shieldPath.getTotalLength() : 200;
    gsap.set(shieldPath, { strokeDasharray: pathLen, strokeDashoffset: pathLen });
    gsap.to(shieldPath, {
      strokeDashoffset: 0, duration: 1.5, ease: "power2.inOut",
      scrollTrigger: { trigger: ".sp-agent-preview--shield", start: "top 80%", once: true }
    });
  }
  if (shieldCheck) {
    var checkLen = shieldCheck.getTotalLength ? shieldCheck.getTotalLength() : 30;
    gsap.set(shieldCheck, { strokeDasharray: checkLen, strokeDashoffset: checkLen });
    gsap.to(shieldCheck, {
      strokeDashoffset: 0, duration: 0.6, ease: "power2.out",
      scrollTrigger: { trigger: ".sp-agent-preview--shield", start: "top 80%", once: true },
      delay: 1.2
    });
  }

  // ─── SHIELD RING ROTATE — Continuous ───
  gsap.to(".sp-shield::before", { rotation: 360, duration: 20, ease: "none", repeat: -1 });
  // CSS pseudo-elements can't be targeted by GSAP, so do it on the shield itself subtly
  gsap.to(".sp-shield", {
    rotation: 0, // target for the pulsing ring effect
    boxShadow: "0 4px 24px rgba(22,163,74,0.2)",
    duration: 2, ease: "power1.inOut", repeat: -1, yoyo: true
  });

  // ─── CAPABILITIES — Scrub-linked stagger ───
  var capGrid = document.querySelector(".sp-capabilities-grid");
  if (capGrid) {
    // Whole grid border reveal
    gsap.to(capGrid, {
      opacity: 1, y: 0, duration: 0.8, ease: quint,
      scrollTrigger: { trigger: capGrid, start: "top 85%", once: true }
    });

    // Each cell content
    ScrollTrigger.batch(".sp-cap", {
      onEnter: function (batch) {
        gsap.to(batch, {
          opacity: 1, y: 0,
          duration: 0.7, ease: quint, stagger: 0.12
        });
      },
      start: "top 88%",
      once: true
    });

    // Icons pop with overshoot
    ScrollTrigger.batch(".sp-cap__icon", {
      onEnter: function (batch) {
        gsap.to(batch, {
          scale: 1, opacity: 1,
          duration: 0.6, ease: "back.out(1.4)", stagger: 0.1, delay: 0.2
        });
      },
      start: "top 90%",
      once: true
    });
  }

  // ─── HOW IT WORKS — Pinned left, steps scroll on right ───
  var howSection = document.querySelector(".sp-how");
  if (howSection) {
    // Left side reveal
    var howTl = gsap.timeline({
      scrollTrigger: { trigger: howSection, start: "top 78%", once: true }
    });
    howTl.to(".sp-how__title", { opacity: 1, y: 0, duration: 0.9, ease: quint }, 0);

    // Split title words
    var howTitleEl = document.querySelector(".sp-how__title");
    if (howTitleEl) {
      var howWords = splitWords(howTitleEl);
      howTl.to(howWords, {
        y: 0, opacity: 1,
        duration: 0.5, stagger: 0.03, ease: quint
      }, 0);
    }

    howTl.to(".sp-how__sub", { opacity: 1, y: 0, duration: 0.7, ease: smooth }, 0.3);

    // Steps — each slides in from right with marker popping
    howTl.to(".sp-step", {
      opacity: 1, x: 0,
      duration: 0.6, ease: quint, stagger: 0.18
    }, 0.4);

    howTl.to(".sp-step__marker", {
      scale: 1, opacity: 1,
      duration: 0.5, ease: "back.out(1.8)", stagger: 0.18
    }, 0.5);

    // Connect step markers with a drawing line
    var stepMarkers = document.querySelectorAll(".sp-step__marker");
    stepMarkers.forEach(function (marker, i) {
      if (i < stepMarkers.length - 1) {
        // Animate the connecting border between steps
        var step = marker.closest(".sp-step");
        if (step) {
          gsap.to(step, {
            borderColor: "var(--sp-border)",
            duration: 0.4, ease: smooth,
            scrollTrigger: { trigger: step, start: "top 80%", once: true },
            delay: 0.3 + i * 0.18
          });
        }
      }
    });
  }

  // ─── FAQ — Individual item reveals ───
  var faqSection = document.querySelector(".sp-faq");
  if (faqSection) {
    var faqTl = gsap.timeline({
      scrollTrigger: { trigger: faqSection, start: "top 78%", once: true }
    });

    // Split FAQ title
    var faqTitleEl = document.querySelector(".sp-faq__title");
    if (faqTitleEl) {
      var faqWords = splitWords(faqTitleEl);
      faqTl.to(faqWords, {
        y: 0, opacity: 1,
        duration: 0.5, stagger: 0.03, ease: quint
      }, 0);
    }

    faqTl.to(".sp-faq__item", {
      opacity: 1, y: 0,
      duration: 0.5, ease: smooth, stagger: 0.1
    }, 0.3);
  }

  // FAQ open/close — smooth height animation
  document.querySelectorAll(".sp-faq__item").forEach(function (item) {
    var summary = item.querySelector("summary");
    var content = item.querySelector("p");
    if (!summary || !content) return;

    summary.addEventListener("click", function (e) {
      e.preventDefault();
      if (item.open) {
        gsap.to(content, {
          height: 0, opacity: 0, paddingBottom: 0,
          duration: 0.3, ease: smooth,
          onComplete: function () { item.open = false; }
        });
      } else {
        item.open = true;
        var h = content.scrollHeight;
        gsap.set(content, { height: 0, opacity: 0 });
        gsap.to(content, {
          height: h, opacity: 1, paddingBottom: "1.25rem",
          duration: 0.4, ease: smooth,
          onComplete: function () { content.style.height = "auto"; }
        });
      }
    });
  });

  // ─── CTA — Scale entrance ───
  var ctaSection = document.querySelector(".sp-cta");
  if (ctaSection) {
    var ctaTl = gsap.timeline({
      scrollTrigger: { trigger: ctaSection, start: "top 82%", once: true }
    });

    // Split CTA title
    var ctaTitleEl = document.querySelector(".sp-cta__title");
    if (ctaTitleEl) {
      var ctaWords = splitWords(ctaTitleEl);
      ctaTl.to(ctaWords, {
        y: 0, opacity: 1,
        duration: 0.5, stagger: 0.025, ease: quint
      }, 0);
    }

    ctaTl.to(".sp-cta__sub", { opacity: 1, y: 0, duration: 0.7, ease: smooth }, 0.3);
    ctaTl.to(".sp-cta .sp-btn", {
      opacity: 1, y: 0, scale: 1,
      duration: 0.7, ease: "back.out(1.4)"
    }, 0.5);
  }

  // ─── FOOTER — Gentle rise ───
  gsap.to(".sp-footer", {
    opacity: 1, y: 0,
    duration: 0.8, ease: smooth,
    scrollTrigger: { trigger: ".sp-footer", start: "top 95%", once: true }
  });

  // ─── MAGNETIC BUTTONS — Cursor-following effect ───
  document.querySelectorAll(".sp-btn--primary").forEach(function (btn) {
    btn.addEventListener("mousemove", function (e) {
      var rect = btn.getBoundingClientRect();
      var x = e.clientX - rect.left - rect.width / 2;
      var y = e.clientY - rect.top - rect.height / 2;
      gsap.to(btn, {
        x: x * 0.15, y: y * 0.15,
        duration: 0.3, ease: smooth
      });
    });
    btn.addEventListener("mouseleave", function () {
      gsap.to(btn, { x: 0, y: 0, duration: 0.5, ease: "elastic.out(1, 0.4)" });
    });
  });

  // ─── SMOOTH ANCHOR SCROLL ───
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (e) {
      var target = document.querySelector(this.getAttribute("href"));
      if (target) {
        e.preventDefault();
        gsap.to(window, {
          scrollTo: { y: target, offsetY: 80 },
          duration: 1.2,
          ease: "power3.inOut"
        });
      }
    });
  });
});
