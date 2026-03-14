// StockPilot Landing — GSAP Animations (Emdash-style)
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

  hero.to(".sp-nav", { opacity: 1, y: 0, duration: 0.7, ease: smooth }, 0.1);
  hero.to(".sp-pill", { opacity: 1, y: 0, duration: 0.6 }, 0.3);
  hero.to(".sp-hero__title", { opacity: 1, y: 0, duration: 1 }, 0.4);
  hero.to(".sp-hero__tagline", { opacity: 1, y: 0, duration: 0.7 }, 0.6);
  hero.to(".sp-hero__sub", { opacity: 1, y: 0, duration: 0.7 }, 0.7);
  hero.to(".sp-hero__actions", { opacity: 1, y: 0, duration: 0.7 }, 0.8);
  hero.to(".sp-hero__proof", { opacity: 1, duration: 0.6 }, 0.9);


  // ─── SCROLL REVEALS ───

  // Arrows
  document.querySelectorAll(".sp-arrows").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, duration: 0.5, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 90%", once: true }
    });
  });

  // Section headers
  document.querySelectorAll(".sp-section__header").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });

  // Feature cards — stagger
  ScrollTrigger.batch(".sp-feature", {
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

  // How it works
  document.querySelectorAll(".sp-how").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });

  // FAQ
  document.querySelectorAll(".sp-faq").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });

  // CTA
  document.querySelectorAll(".sp-cta").forEach(function (el) {
    gsap.to(el, {
      opacity: 1, y: 0, duration: 0.8, ease: smooth,
      scrollTrigger: { trigger: el, start: "top 85%", once: true }
    });
  });

  // ─── SIDEBAR SCROLL SPY ───
  var sidebar = document.querySelector(".sp-sidebar");
  var sidebarLinks = document.querySelectorAll(".sp-sidebar__link");
  var sections = [];

  sidebarLinks.forEach(function (link) {
    var id = link.getAttribute("data-section");
    var el = document.getElementById(id);
    if (el) sections.push({ id: id, el: el, link: link });
  });

  // Show sidebar after scrolling past the nav
  if (sidebar) {
    ScrollTrigger.create({
      trigger: ".sp-hero",
      start: "top top",
      onUpdate: function (self) {
        if (self.scroll() > 300) {
          sidebar.classList.add("is-visible");
        } else {
          sidebar.classList.remove("is-visible");
        }
      }
    });
  }

  // Update active section on scroll
  ScrollTrigger.create({
    start: 0,
    end: "max",
    onUpdate: function () {
      var scrollY = window.scrollY + window.innerHeight * 0.35;
      var active = sections[0];

      for (var i = sections.length - 1; i >= 0; i--) {
        if (sections[i].el.offsetTop <= scrollY) {
          active = sections[i];
          break;
        }
      }

      sidebarLinks.forEach(function (link) {
        link.classList.remove("is-active");
      });
      if (active) {
        active.link.classList.add("is-active");
      }
    }
  });

  // ─── SMOOTH ANCHOR SCROLL ───
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener("click", function (e) {
      var target = document.querySelector(this.getAttribute("href"));
      if (target) {
        e.preventDefault();
        gsap.to(window, {
          scrollTo: { y: target, offsetY: 60 },
          duration: 1,
          ease: "power2.inOut"
        });
      }
    });
  });
});
