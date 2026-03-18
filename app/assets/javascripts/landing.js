// StockPilot Landing — GSAP Animations
document.addEventListener("DOMContentLoaded", function () {
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches || typeof gsap === "undefined") {
    return;
  }

  document.body.classList.add("gsap-ready");
  gsap.registerPlugin(ScrollTrigger);

  var smooth = "power3.out";
  var expo = "expo.out";

  // ─── HERO ENTRANCE ───
  var hero = gsap.timeline({ defaults: { ease: expo } });

  hero.to(".lp-nav", { opacity: 1, y: 0, duration: 0.7, ease: smooth }, 0.1);
  hero.to(".lp-hero__headline", { opacity: 1, y: 0, duration: 1 }, 0.3);
  hero.to(".lp-hero__subtitle", { opacity: 1, y: 0, duration: 0.7 }, 0.5);
  hero.to(".lp-hero__media", { opacity: 1, y: 0, duration: 0.8 }, 0.6);

  // ─── SCROLL REVEALS ───

  // Bento grid cells — stagger
  ScrollTrigger.batch(".lp-grid__cell", {
    onEnter: function (batch) {
      gsap.to(batch, {
        opacity: 1, y: 0,
        duration: 0.6, ease: smooth,
        stagger: 0.08
      });
    },
    start: "top 88%",
    once: true
  });

  // Statement CTA
  document.querySelectorAll(".lp-statement").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });
});
