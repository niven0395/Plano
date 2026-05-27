import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Matches Plano/DesignSystem/AppTheme.swift
        ink: {
          DEFAULT: "#24211F",
          muted: "#423D38",
          subtle: "#7A7470",
        },
        accent: {
          DEFAULT: "#1F1C19",
          on: "#FDFCFA",
        },
        surface: {
          page: "#F2F0EB",
          pageEnd: "#E8E6E1",
          card: "#F7F6F4",
          raised: "#FDFCFA",
          dark: "#19170F",
          darkRaised: "#23201B",
        },
        line: "rgba(0,0,0,0.075)",
        lineDark: "rgba(255,255,255,0.08)",
        danger: {
          bg: "#FEF2F2",
          border: "#FECACA",
          ink: "#B91C1C",
        },
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "SF Pro Text",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "sans-serif",
        ],
      },
      borderRadius: {
        card: "30px",
        button: "20px",
        field: "14px",
        pill: "999px",
      },
      boxShadow: {
        card: "0 12px 18px rgba(0,0,0,0.04)",
        raised: "0 6px 10px rgba(0,0,0,0.03)",
        button: "0 2px 6px rgba(0,0,0,0.08)",
      },
      letterSpacing: {
        tightest: "-0.035em",
      },
      backgroundImage: {
        "page-gradient":
          "linear-gradient(135deg, #F2F0EB 0%, #E8E6E1 100%)",
        "page-gradient-dark":
          "linear-gradient(135deg, #19170F 0%, #23201B 100%)",
      },
    },
  },
  plugins: [],
  darkMode: "media",
};

export default config;
