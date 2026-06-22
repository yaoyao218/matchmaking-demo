/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#2563EB',
        golden: '#10B981',
        conflict: '#EF4444',
      },
    },
  },
  plugins: [],
}

