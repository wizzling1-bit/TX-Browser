---
version: 1.0.0
name: Tx-Browser-Design-System
description: Premium, minimalist, spatial, content-first, bento-grid, subtle frosted glass, layered depth, and refined spring motion. Color palette rooted in Cream (#EDF1D6), Sage (#9DC08B), Medium Green (#609966), and Deep Forest (#40513B). In dark mode, primary and secondary accents intentionally swap to maintain contrast.

colors:
  # Light Mode Tokens
  bg-light: "#EDF1D6"
  surface-light: "#F7F8EB"
  primary-light: "#609966"
  secondary-light: "#9DC08B"
  text-primary-light: "#40513B"
  text-secondary-light: "#60705A"
  border-light: "#D5DEC5"

  # Dark Mode Tokens (Primary/Secondary SWAP intentionally)
  bg-dark: "#1B2419"
  surface-dark: "#263323"
  primary-dark: "#9DC08B"
  secondary-dark: "#609966"
  text-primary-dark: "#EDF1D6"
  text-secondary-dark: "#C8D3BD"
  border-dark: "#40513B"

  # Semantic Tokens
  success-light: "#4C9A5A"
  success-dark: "#7FCB8F"
  error-light: "#B3453C"
  error-dark: "#E08B83"
  warning-light: "#C7893A"
  warning-dark: "#E0AE6F"

  # Privacy & Glass Overlays
  private-accent: "#40513B"
  overlay-scrim: "rgba(27, 36, 25, 0.55)"
  glass-light: "rgba(247, 248, 235, 0.65)"
  glass-dark: "rgba(38, 51, 35, 0.65)"

typography:
  display:
    fontFamily: "Inter, sans-serif"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: -0.3px
  heading:
    fontFamily: "Inter, sans-serif"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: -0.1px
  body:
    fontFamily: "Inter, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.4
  body-medium:
    fontFamily: "Inter, sans-serif"
    fontSize: 15px
    fontWeight: 500
    lineHeight: 1.4
  label:
    fontFamily: "Inter, sans-serif"
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.3
  label-uppercase:
    fontFamily: "Inter, sans-serif"
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0.8px
  mono:
    fontFamily: "JetBrains Mono, monospace"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.3

rounded:
  sm: 8px
  md: 16px
  lg: 24px
  full: 999px

spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px

motion:
  micro: 120ms easeOut
  standard: 220ms easeOutCubic
  emphasis: 350ms easeOutBack
  stagger-step: 40ms
  reduced: 100ms easeOut

components:
  glass-surface:
    blur: 20px
    border: "1px solid rgba(213, 222, 197, 0.4)"
    shadow: "0 4px 12px rgba(64, 81, 59, 0.12)"
  omnibox:
    height-idle: 48px
    height-focused: 56px
    radius: "{rounded.lg}"
  bottom-nav:
    height: 56px
    radius: "{rounded.full}"
    margin-bottom: 16px
  bento-card:
    radius: "{rounded.md}"
    shadow: "0 1px 3px rgba(64, 81, 59, 0.08)"
    press-scale: 0.96
  button-primary:
    height: 48px
    radius: "{rounded.sm}"
    padding: "0 16px"
---

# Tx Browser Design System Specification

## Core Philosophy
1. **Content-First Canvas**: The web page is the hero. Chrome recedes cleanly into frosted glass floating pills that auto-hide upon downward scroll and smoothly re-emerge on upward gesture.
2. **Spatial Bento Grid**: Clean modular cards with layered depth, generous padding, and subtle shadows.
3. **Calm Nature Palette**: Warm Cream background, Sage accents, and Deep Forest ink create a focused, distraction-free environment.
4. **Adaptive Dark Mode**: Dark mode is not an algorithmic inversion; primary and secondary accents swap deliberately so Sage `#9DC08B` shines against the Deep Forest `#1B2419` backdrop.
