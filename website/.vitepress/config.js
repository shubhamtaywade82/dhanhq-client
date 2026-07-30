import { defineConfig } from "vitepress";

export default defineConfig({
  lang: "en-US",
  base: "/dhanhq-client/",
  title: "DhanHQ Ruby SDK",
  description:
    "Production-grade Ruby SDK and client for Dhan API v2 with REST APIs, WebSocket market data, typed models, dry-validation contracts and trading workflows for Ruby on Rails and standalone Ruby applications.",

  head: [
    ["link", { rel: "icon", href: "/favicon.ico" }],
    [
      "meta",
      { name: "keywords", content: "dhanhq, ruby, dhan-api, trading-api, algorithmic-trading, nse, bse, websocket, ruby-gem, rails" },
    ],
    ["meta", { property: "og:title", content: "DhanHQ Ruby SDK | Dhan API Client for Ruby" }],
    [
      "meta",
      {
        property: "og:description",
        content:
          "Production-grade Ruby gem for Dhan API v2 with WebSocket market data, typed models, dry-validation contracts and Rails integration.",
      },
    ],
    ["meta", { property: "og:url", content: "https://shubhamtaywade82.github.io/dhanhq-client/" }],
    ["meta", { property: "og:type", content: "website" }],
    ["meta", { name: "twitter:card", content: "summary_large_image" }],
    ["link", { rel: "canonical", href: "https://shubhamtaywade82.github.io/dhanhq-client/" }],
  ],

  themeConfig: {
    nav: [
      { text: "Home", link: "/" },
      { text: "Getting Started", link: "/getting-started" },
      { text: "API", link: "/api/orders" },
      { text: "WebSocket", link: "/websocket/market-feed" },
      { text: "Rails", link: "/rails" },
      { text: "GitHub", link: "https://github.com/shubhamtaywade82/dhanhq-client" },
    ],

    sidebar: [
      {
        text: "Getting Started",
        items: [
          { text: "Installation", link: "/getting-started" },
          { text: "Configuration", link: "/getting-started#configuration" },
          { text: "Authentication", link: "/getting-started#authentication" },
        ],
      },
      {
        text: "API Reference",
        items: [
          { text: "Orders", link: "/api/orders" },
          { text: "Super Orders", link: "/api/super-orders" },
          { text: "Portfolio & Funds", link: "/api/portfolio" },
          { text: "Instruments & Option Chain", link: "/api/instruments" },
          { text: "Market Feed", link: "/api/market-feed" },
          { text: "Historical Data", link: "/api/historical-data" },
        ],
      },
      {
        text: "WebSocket",
        items: [
          { text: "Market Feed", link: "/websocket/market-feed" },
          { text: "Order Updates", link: "/websocket/order-updates" },
          { text: "Protocol Reference", link: "/websocket/protocol" },
        ],
      },
      {
        text: "Rails Integration",
        link: "/rails",
        items: [
          { text: "ActionCable", link: "/rails#actioncable" },
          { text: "Generators", link: "/rails#generators" },
        ],
      },
      {
        text: "Analytics",
        items: [
          { text: "Technical Analysis", link: "/analytics/technical-analysis" },
        ],
      },
      {
        text: "Testing & Best Practices",
        link: "/testing",
      },
      {
        text: "Reference",
        items: [
          { text: "Architecture", link: "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/ARCHITECTURE.md" },
          { text: "Authentication (Detailed)", link: "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/AUTHENTICATION.md" },
          { text: "WebSocket Protocol", link: "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/WEBSOCKET_PROTOCOL.md" },
          { text: "Configuration", link: "https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/CONFIGURATION.md" },
        ],
      },
    ],

    socialLinks: [
      { icon: "github", link: "https://github.com/shubhamtaywade82/dhanhq-client" },
      { icon: "ruby", link: "https://rubygems.org/gems/DhanHQ" },
    ],

    footer: {
      message: "Community project — not affiliated with Dhan. MIT License.",
      copyright: `Copyright ${new Date().getFullYear()} Shubham Taywade`,
    },

    editLink: {
      pattern: "https://github.com/shubhamtaywade82/dhanhq-client/edit/main/website/:path",
      text: "Edit this page on GitHub",
    },

    search: { provider: "local" },
  },

  lastUpdated: true,
  cleanUrls: true,
});
