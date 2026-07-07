/**
 * Inline icon set — 20×20 stroke icons in a consistent 1.8pt weight.
 * Dependency-free (no icon package) and tree-shaken by usage.
 */

const base = {
  viewBox: "0 0 20 20",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
};

export const IconHome = (
  <svg {...base}>
    <path d="M3 8.5 10 3l7 5.5V16a1 1 0 0 1-1 1h-4v-4.5H8V17H4a1 1 0 0 1-1-1V8.5Z" />
  </svg>
);

export const IconMembership = (
  <svg {...base}>
    <path d="M10 2.5l2.1 4.3 4.7.7-3.4 3.3.8 4.7L10 13.3l-4.2 2.2.8-4.7L3.2 7.5l4.7-.7L10 2.5Z" />
  </svg>
);

export const IconBuildings = (
  <svg {...base}>
    <path d="M3 17h14M4 17V5a1 1 0 0 1 1-1h5v13M10 8h5a1 1 0 0 1 1 1v8M6.5 7h1M6.5 10h1M6.5 13h1M12.5 11h1M12.5 14h1" />
  </svg>
);

export const IconGauge = (
  <svg {...base}>
    <path d="M3.5 12.5a6.5 6.5 0 1 1 13 0M10 12.5l3-3.5" />
    <circle cx="10" cy="12.5" r="1" />
  </svg>
);

export const IconPayments = (
  <svg {...base}>
    <rect x="2.5" y="5" width="15" height="10.5" rx="2" />
    <path d="M2.5 8.5h15M5.5 12.5h3" />
  </svg>
);
