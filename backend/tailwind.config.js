/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx,mdx}',
    './context/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        tx: {
          bg: '#080D09',
          surface: '#0F1611',
          card: '#141E16',
          cardHover: '#1B271E',
          surfaceInset: '#0A110C',
          border: '#1F2E22',
          borderLight: '#2D4231',
          borderFocus: '#406346',
          primary: '#22C55E',
          primaryHover: '#16A34A',
          primaryDark: '#14532D',
          primaryMuted: '#14532D40',
          sage: '#86EFAC',
          cream: '#F4F8F5',
          text: '#E5EDE7',
          textMuted: '#97ABA0',
          textDim: '#657A69',
          gold: '#E5A93C',
          goldLight: '#F3C568',
          goldDark: '#B87E1F',
          goldMuted: 'rgba(229, 169, 60, 0.15)',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        'glass': '0 8px 32px 0 rgba(0, 0, 0, 0.45)',
        'glow-primary': '0 0 20px -3px rgba(34, 197, 94, 0.25)',
        'glow-subtle': '0 0 15px -3px rgba(34, 197, 94, 0.12)',
        'card-elevated': '0 4px 20px -2px rgba(0, 0, 0, 0.35)',
      },
      animation: {
        'shimmer': 'shimmer 2s infinite linear',
        'fade-in': 'fadeIn 0.2s ease-out',
        'slide-up': 'slideUp 0.25s cubic-bezier(0.16, 1, 0.3, 1)',
      },
      keyframes: {
        shimmer: {
          '0%': { transform: 'translateX(-100%)' },
          '100%': { transform: 'translateX(100%)' },
        },
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
};
