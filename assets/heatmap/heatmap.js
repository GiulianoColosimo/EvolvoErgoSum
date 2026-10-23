/*
 * GitHub-style contribution heatmap. No dependencies.
 *
 * Usage:
 *   <link rel="stylesheet" href="heatmap.css">
 *   <div class="hm" data-heatmap-src="heatmap.json"></div>
 *   <script src="heatmap.js" defer></script>
 *
 * heatmap.json is an array of days:
 *   [{"date": "2026-10-16", "activities": [{"activity": "Wrote tests", "n": 2}]}, ...]
 */
(function () {
  "use strict";

  var SVG_NS = "http://www.w3.org/2000/svg";
  var CELL = 11, GAP = 3, STEP = CELL + GAP;
  var LEFT = 28, TOP = 18;                     // room for weekday and month labels
  var DAY_MS = 86400000;
  var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  function parseDate(s) {
    var p = s.split("-").map(Number);
    return new Date(Date.UTC(p[0], p[1] - 1, p[2]));
  }

  function formatDate(d, opts) {
    return d.toLocaleDateString(undefined, Object.assign({ timeZone: "UTC" }, opts));
  }

  function el(tag, attrs, parent, ns) {
    var node = ns ? document.createElementNS(SVG_NS, tag) : document.createElement(tag);
    for (var k in attrs) node.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(node);
    return node;
  }

  // Five levels like GitHub: 0, then quartiles of the non-zero counts
  function levelFn(counts) {
    var nz = counts.filter(function (c) { return c > 0; }).sort(function (a, b) { return a - b; });
    if (!nz.length) return function () { return 0; };
    var q = function (p) { return nz[Math.floor(p * (nz.length - 1))]; };
    var t1 = q(0.25), t2 = q(0.5), t3 = q(0.75);
    return function (c) {
      return c === 0 ? 0 : c <= t1 ? 1 : c <= t2 ? 2 : c <= t3 ? 3 : 4;
    };
  }

  // ---- Tooltip (one shared element, floats above the page) ------------------
  var tip;
  function getTip() {
    if (!tip) {
      tip = el("div", { "class": "hm-tooltip", role: "tooltip" }, document.body);
      window.addEventListener("scroll", hideTip, true);
      window.addEventListener("resize", hideTip);
    }
    return tip;
  }

  function showTip(cell, day, nounOne, nounMany) {
    var t = getTip();
    t.textContent = "";
    var head = el("div", {}, t);
    el("strong", {}, head).textContent =
      day.count + " " + (day.count === 1 ? nounOne : nounMany);
    head.appendChild(document.createTextNode(
      " on " + formatDate(day.date, { weekday: "short", day: "numeric", month: "short", year: "numeric" })));
    if (day.activities.length) {
      var ul = el("ul", {}, t);
      day.activities.forEach(function (a) {
        var li = el("li", {}, ul);
        li.textContent = a.activity;
        if (a.n > 1) el("span", { "class": "hm-times" }, li).textContent = " ×" + a.n;
      });
    }

    // Centre above the tile; flip below if there is no room; keep inside the window
    t.classList.add("hm-show");
    var r = cell.getBoundingClientRect(), b = t.getBoundingClientRect(), m = 8;
    var left = Math.min(Math.max(m, r.left + r.width / 2 - b.width / 2), window.innerWidth - b.width - m);
    var top = r.top - b.height - m;
    if (top < m) top = r.bottom + m;
    t.style.left = left + "px";
    t.style.top = top + "px";
  }

  function hideTip() { if (tip) tip.classList.remove("hm-show"); }

  // ---- Render -----------------------------------------------------------------
  function render(container, data) {
    // Word used in the tooltip and footer. Override per heatmap with
    // data-noun="entry" data-noun-plural="entries".
    var nounOne  = container.dataset.noun       || "contribution";
    var nounMany = container.dataset.nounPlural || (nounOne + "s");

    var byDate = {};
    data.forEach(function (d) { byDate[d.date] = d.activities || []; });
    var dates = Object.keys(byDate).sort();
    if (!dates.length) return;

    // Every day from first to last, including days missing from the data
    var start = parseDate(dates[0]), end = parseDate(dates[dates.length - 1]);
    var days = [];
    for (var t = start.getTime(); t <= end.getTime(); t += DAY_MS) {
      var date = new Date(t), key = date.toISOString().slice(0, 10);
      var acts = byDate[key] || [];
      var count = acts.reduce(function (s, a) { return s + (a.n || 1); }, 0);
      days.push({ date: date, activities: acts, count: count });
    }
    var level = levelFn(days.map(function (d) { return d.count; }));
    var weekStart = start.getTime() - start.getUTCDay() * DAY_MS;   // Sunday on or before start
    var nWeeks = Math.floor((end.getTime() - weekStart) / DAY_MS / 7) + 1;

    container.textContent = "";
    var scroll = el("div", { "class": "hm-scroll" }, container);
    var svg = el("svg", {
      "class": "hm-svg",
      viewBox: "0 0 " + (LEFT + nWeeks * STEP) + " " + (TOP + 7 * STEP),
      role: "img",
      "aria-label": "Contribution heatmap"
    }, scroll, true);

    // Weekday labels
    [[1, "Mon"], [3, "Wed"], [5, "Fri"]].forEach(function (d) {
      el("text", { x: LEFT - 6, y: TOP + d[0] * STEP + CELL - 2, "text-anchor": "end" }, svg, true)
        .textContent = d[1];
    });

    var lastLabelCol = -10;
    days.forEach(function (day, i) {
      var col = Math.floor((day.date.getTime() - weekStart) / DAY_MS / 7);
      var row = day.date.getUTCDay();
      el("rect", {
        "class": "hm-cell hm-l" + level(day.count),
        x: LEFT + col * STEP, y: TOP + row * STEP,
        width: CELL, height: CELL, rx: 2, ry: 2,
        "data-i": i
      }, svg, true);

      // Month label above the first column of each month (skip if too crowded)
      if (day.date.getUTCDate() === 1 && col - lastLabelCol >= 3 && col < nWeeks - 1) {
        el("text", { x: LEFT + col * STEP, y: TOP - 6 }, svg, true)
          .textContent = MONTHS[day.date.getUTCMonth()];
        lastLabelCol = col;
      }
    });

    // Hover (mouse) and tap (touch) both arrive as pointer events
    svg.addEventListener("pointerover", function (e) {
      var i = e.target.getAttribute("data-i");
      if (i !== null) showTip(e.target, days[i], nounOne, nounMany);
    });
    svg.addEventListener("pointerleave", hideTip);

    // Footer: total and Less ... More legend
    var total = days.reduce(function (s, d) { return s + d.count; }, 0);
    var footer = el("div", { "class": "hm-footer" }, container);
    el("span", {}, footer).textContent = total + " " + nounMany + ", " +
      formatDate(start, { month: "short", year: "numeric" }) + " – " +
      formatDate(end, { month: "short", year: "numeric" });
    var legend = el("span", { "class": "hm-legend" }, footer);
    el("span", {}, legend).textContent = "Less";
    for (var l = 0; l < 5; l++) el("i", { "class": "hm-l" + l }, legend);
    el("span", {}, legend).textContent = "More";

    // On narrow screens show the most recent weeks first, like GitHub
    scroll.scrollLeft = scroll.scrollWidth;
  }

  function init() {
    document.querySelectorAll("[data-heatmap-src]").forEach(function (node) {
      fetch(node.getAttribute("data-heatmap-src"))
        .then(function (r) {
          if (!r.ok) throw new Error(r.status + " " + r.statusText);
          return r.json();
        })
        .then(function (data) { render(node, data); })
        .catch(function (err) {
          node.textContent = "Could not load heatmap data (" + err.message + ").";
        });
    });
  }

  window.ContributionHeatmap = { render: render };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
