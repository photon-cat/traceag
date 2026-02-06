/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'panel': {
          'bg': 'rgba(30, 41, 59, 0.95)',
          'border': 'rgba(71, 85, 105, 0.5)',
        },
        'guidance': {
          'green': '#22c55e',
          'red': '#ef4444',
          'active': '#3b82f6',
        }
      }
    },
  },
  plugins: [],
}
