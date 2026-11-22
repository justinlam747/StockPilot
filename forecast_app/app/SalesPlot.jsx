import { useEffect, useRef } from 'react';
import { BarController, BarElement, CategoryScale, Chart, LinearScale, LineController, LineElement, PointElement } from 'chart.js';

Chart.register(BarController, BarElement, CategoryScale, LinearScale, LineController, LineElement, PointElement);

const shortDate = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
const monthYear = new Intl.DateTimeFormat('en-US', { month: 'short', year: 'numeric', timeZone: 'UTC' });
const compact = new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 });
const dashPatterns = [[7, 4], [2, 3], [8, 3, 2, 3], [1, 4], [10, 4]];
export const peerDash = pattern => dashPatterns[Math.max(0, pattern - 1) % dashPatterns.length];

function salesSeries(points, models, color, futureIndex) {
  const actuals = { type: 'bar', label: 'Actual sales', data: points.map(p => p.actual),
    backgroundColor: color('--bar-fill'), barPercentage: .8, categoryPercentage: .85, maxBarThickness: 42, order: 2 };
  const gaps = points.map((point, i) => point.actual == null && (futureIndex < 0 || i < futureIndex) ? 0 : null);
  const omitted = gaps.includes(0) ? [{ type: 'line', label: 'Actual unobserved', data: gaps, showLine: false,
    pointStyle: 'crossRot', pointRadius: 4, pointBorderWidth: 1.5, pointBorderColor: color('--muted'), clip: 5 }] : [];
  return [actuals, ...omitted, ...models.map(({ id, name, pattern }) => {
    const primary = id === 'xgboost';
    const ink = color(primary ? '--accent' : '--muted');
    return { type: 'line', label: name + ' forecast', data: points.map(p => p.forecasts[id] ?? null),
      spanGaps: false, borderColor: ink, backgroundColor: ink, borderWidth: primary ? 2.5 : 1.75,
      borderDash: primary ? [] : peerDash(pattern), pointBackgroundColor: color('--paper'), pointBorderColor: ink,
      pointRadius: points.length <= 26 ? (primary ? 3 : 2) : 1, order: primary ? 0 : 1 };
  })];
}

// Chart.js owns both scales. The keyboard and pointer surface tracks its plot area after every resize.
function plotLayout(layer, futureIndex, fill) {
  return {
    id: 'weeklySalesLayout',
    afterLayout({ chartArea: { left, top, width, height } }) {
      Object.assign(layer.style, { left: left + 'px', top: top + 'px', width: width + 'px', height: height + 'px' });
    },
    beforeDraw({ ctx, chartArea, scales }) {
      if (futureIndex < 0) return;
      const start = futureIndex === 0 ? chartArea.left :
        (scales.x.getPixelForValue(futureIndex - 1) + scales.x.getPixelForValue(futureIndex)) / 2;
      ctx.save();
      ctx.fillStyle = fill;
      ctx.fillRect(start, chartArea.top, chartArea.right - start, chartArea.height);
      ctx.restore();
    },
  };
}

export default function SalesPlot({ points, models, futureIndex, children }) {
  const canvas = useRef(null);
  const layer = useRef(null);
  useEffect(() => {
    const style = getComputedStyle(canvas.current);
    const color = token => style.getPropertyValue(token).trim();
    const formatter = points.length > 52 ? monthYear : shortDate;
    const labels = points.map(point => formatter.format(new Date(point.date + 'T00:00:00Z')));
    const font = { family: style.fontFamily, weight: '500', size: 12 };
    const chart = new Chart(canvas.current, {
      type: 'bar',
      data: { labels, datasets: salesSeries(points, models, color, futureIndex) },
      plugins: [plotLayout(layer.current, futureIndex, color('--surface'))],
      options: {
        responsive: true, maintainAspectRatio: false, animation: false, events: [],
        scales: {
          x: { type: 'category', offset: true, grid: { display: false }, border: { color: color('--line') },
            ticks: { font, color: color('--muted'), autoSkip: true, autoSkipPadding: 20, maxTicksLimit: 9, maxRotation: 0 } },
          y: { type: 'linear', beginAtZero: true, suggestedMax: 1, grid: { color: color('--rule'), drawTicks: false },
            border: { display: false, dash: [2, 4] }, ticks: { font, color: color('--muted'), padding: 8, maxTicksLimit: 6,
              callback: value => Math.abs(value) >= 10000 ? compact.format(value) : value } },
        },
      },
    });
    // A restored local run may render before the bundled font has finished loading.
    document.fonts?.ready.then(() => { if (chart.canvas) chart.update('none'); });
    return () => chart.destroy();
  }, [points, models, futureIndex]);
  return <div className="fc-chart">
    <canvas ref={canvas} aria-hidden="true" />
    <div className="fc-interaction-layer" ref={layer}>{children}</div>
  </div>;
}
