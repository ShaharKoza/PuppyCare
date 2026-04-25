/* ════════════════════════════════════════════
   PUPPYCARE — LANDING PAGE SCRIPTS
   script.js
════════════════════════════════════════════ */

'use strict';

/* ──────────────────────────────
   1. SCROLL REVEAL
────────────────────────────── */
(function initReveal() {
  const elements = document.querySelectorAll('.reveal');
  if (!elements.length) return;

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target); // fire once
        }
      });
    },
    { threshold: 0.12 }
  );

  elements.forEach((el) => observer.observe(el));
})();


/* ──────────────────────────────
   2. ACTIVE NAV LINK ON SCROLL
────────────────────────────── */
(function initActiveNav() {
  const sections  = document.querySelectorAll('section[id]');
  const navLinks  = document.querySelectorAll('.nav-links a');
  const navbar    = document.getElementById('navbar');

  if (!sections.length || !navLinks.length) return;

  // Update navbar shadow on scroll
  function handleScroll() {
    navbar.classList.toggle('scrolled', window.scrollY > 8);
  }
  window.addEventListener('scroll', handleScroll, { passive: true });

  // Update active link with IntersectionObserver.
  // Only update when the intersecting section actually has a corresponding nav link,
  // so sections without nav entries (e.g. #value) do not clear the active state.
  const navObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        const id = entry.target.id;
        const hasLink = Array.from(navLinks).some(
          (link) => link.getAttribute('href') === '#' + id
        );
        if (!hasLink) return;
        navLinks.forEach((link) => {
          const isActive = link.getAttribute('href') === '#' + id;
          link.classList.toggle('active', isActive);
        });
      });
    },
    {
      rootMargin: '-32% 0px -58% 0px',
      threshold: 0
    }
  );

  sections.forEach((section) => navObserver.observe(section));
})();


/* ──────────────────────────────
   3. MOBILE BURGER MENU
────────────────────────────── */
(function initBurger() {
  const burger   = document.getElementById('nav-burger');
  const navLinks = document.getElementById('nav-links');
  if (!burger || !navLinks) return;

  burger.addEventListener('click', () => {
    const isOpen = navLinks.classList.toggle('open');
    burger.setAttribute('aria-expanded', String(isOpen));
  });

  // Close menu when a nav link is clicked
  navLinks.querySelectorAll('a').forEach((link) => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      burger.setAttribute('aria-expanded', 'false');
    });
  });

  // Close on outside click
  document.addEventListener('click', (e) => {
    if (!burger.contains(e.target) && !navLinks.contains(e.target)) {
      navLinks.classList.remove('open');
      burger.setAttribute('aria-expanded', 'false');
    }
  });
})();


/* ──────────────────────────────
   4. COPY PROJECT INFO
────────────────────────────── */
function copyInfo() {
  const raw = `{
  "project"      :  "PuppyCare — Smart Kennel Monitoring for Puppies",
  "authors"      :  "Shahar Koza & Daniella Shemesh",
  "institution"  :  "Ono Academic College",
  "year"         :  2026,
  "platform"     :  "iOS 16+ (SwiftUI) + Raspberry Pi",
  "stack"        :  "SwiftUI · Firebase RTDB · FCM · Node.js · Python",
  "sensors"      :  "DHT22/AM2302 · LDR · KY-038 · HC-SR501 PIR (active HIGH)",
  "pi_script"    :  "main_sensors.py — Production Edition",
  "category"     :  "Smart Pet Care / IoT + Mobile",
  "repository"   :  "https://github.com/ShaharKoza/PuppyCare",
  "license"      :  "MIT",
  "version"      :  "1.0 · April 2026",
  "type"         :  "Final Year Project · IoT + Mobile Application"
}`;

  const btn = document.getElementById('copy-btn');
  if (!btn) return;

  navigator.clipboard.writeText(raw)
    .then(() => {
      btn.innerHTML = `
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"
             style="width:13px;height:13px" aria-hidden="true">
          <polyline points="20 6 9 17 4 12"/>
        </svg>
        Copied!`;
      btn.style.background = 'rgba(39,201,63,0.18)';
      btn.style.borderColor = 'rgba(39,201,63,0.40)';
      btn.style.color = '#4CD964';

      setTimeout(() => {
        btn.innerHTML = `
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
               style="width:13px;height:13px" aria-hidden="true">
            <rect x="9" y="9" width="13" height="13" rx="2"/>
            <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
          </svg>
          Copy Info`;
        btn.style.background = '';
        btn.style.borderColor = '';
        btn.style.color = '';
      }, 2600);
    })
    .catch(() => {
      // Fallback for browsers without clipboard API
      const ta = document.createElement('textarea');
      ta.value = raw;
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);

      btn.textContent = 'Copied!';
      setTimeout(() => { btn.textContent = 'Copy Info'; }, 2400);
    });
}
