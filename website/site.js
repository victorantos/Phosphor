/* phosphor.online — progressive enhancement only. Everything below is optional;
   the page is fully readable and navigable with JavaScript disabled. */
(function () {
  'use strict';

  /* ---- Mobile menu sheet ------------------------------------------------ */
  var toggle = document.querySelector('[data-nav-toggle]');
  var sheet = document.getElementById('menu-sheet');
  var scrim = document.getElementById('menu-scrim');

  function setSheet(open) {
    if (!sheet || !scrim || !toggle) return;
    sheet.hidden = !open;
    scrim.hidden = !open;
    toggle.setAttribute('aria-expanded', String(open));
    document.body.style.overflow = open ? 'hidden' : '';
    if (open) {
      var first = sheet.querySelector('a');
      if (first) first.focus();
    } else {
      toggle.focus();
    }
  }

  if (toggle && sheet && scrim) {
    toggle.addEventListener('click', function () { setSheet(sheet.hidden); });
    scrim.addEventListener('click', function () { setSheet(false); });
    sheet.addEventListener('click', function (e) {
      if (e.target.closest('a')) setSheet(false);
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !sheet.hidden) setSheet(false);
    });
  }

  /* ---- Phone mock: scale the 402px frame to its column ------------------ */
  var stage = document.querySelector('[data-phone-stage]');
  if (stage) {
    var fit = function () {
      var avail = stage.parentElement.clientWidth;
      var scale = Math.min(1, avail / 402);
      stage.style.setProperty('--phone-scale', scale.toFixed(4));
    };
    fit();
    if (typeof ResizeObserver !== 'undefined') {
      new ResizeObserver(fit).observe(stage.parentElement);
    } else {
      window.addEventListener('resize', fit);
    }
  }

  /* ---- Comparison: one competitor column at a time on narrow screens ---- */
  var cmp = document.querySelector('[data-cmp]');
  var tabs = document.querySelector('[data-cmp-tabs]');
  if (cmp && tabs) {
    tabs.addEventListener('click', function (e) {
      var btn = e.target.closest('button');
      if (!btn) return;
      cmp.dataset.comp = btn.dataset.comp;
      tabs.querySelectorAll('button').forEach(function (b) {
        b.setAttribute('aria-selected', String(b === btn));
      });
    });
  }

  /* ---- FAQ: keep one answer open at a time ----------------------------- */
  var faqs = document.querySelectorAll('.faq-list .faq-item');
  faqs.forEach(function (item) {
    item.addEventListener('toggle', function () {
      if (!item.open) return;
      faqs.forEach(function (other) { if (other !== item) other.open = false; });
    });
  });

  /* ---- Sticky CTA on mobile, once the hero is behind you --------------- */
  var sticky = document.querySelector('[data-sticky-cta]');
  if (sticky) {
    var sync = function () {
      var show = window.matchMedia('(max-width: 719px)').matches &&
                 window.scrollY > 560 &&
                 (!sheet || sheet.hidden);
      sticky.hidden = !show;
      document.documentElement.style.setProperty('--sticky-pad', show ? '72px' : '0px');
    };
    sync();
    window.addEventListener('scroll', sync, { passive: true });
    window.addEventListener('resize', sync);
  }
})();
