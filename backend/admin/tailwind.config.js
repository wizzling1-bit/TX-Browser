/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        tx: {
          bg: '#0B110C',
          surface: '#121A13',
          card: '#182319',
          cardHover: '#1F2C20',
          border: '#273829',
          borderLight: '#394E3B',
          primary: '#609966',
          primaryHover: '#73B079',
          primaryDark: '#40534C',
          sage: '#9DC08B',
          cream: '#EDF1D6',
          text: '#F1F6F2',
          textMuted: '#9BB09D',
          textDim: '#647566',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [],
};
