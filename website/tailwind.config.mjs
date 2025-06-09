// tailwind.config.mjs
export default {
  content: ["./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}"],
  theme: {
    extend: {
      // Custom gradient utilities
      backgroundImage: {
        "gradient-brand":
          "linear-gradient(to bottom right, #f472b6, #a855f7, #4f46e5)",
        "gradient-section": "linear-gradient(to right, #67e8f9, #14b8a6)",
      },
      // Custom backdrop blur utilities
      backdropBlur: {
        glass: "16px",
      },
    },
  },
  plugins: [],
};
