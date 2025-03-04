import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Service Action",
  description: "A terse convention for business logic",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Home', link: '/' },
      { text: 'User Guide', link: '/guide' }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'About', link: '/about/' },
          { text: 'User Guide', link: '/guide/' },
          { text: 'Getting Started', link: '/getting-started/' },
        ]
      },
      {
        text: 'Advanced Usage',
        items: [
          { text: 'Validating User Input', link: '/advanced/validating-user-input' },
        ]
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
    ]
  }
})
