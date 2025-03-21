import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Service Action",
  description: "A terse convention for business logic",
  base: "/service_action/",
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
          { text: 'Summary Overview', link: '/guide/' },
        ]
      },
      {
        text: 'Getting Started',
        items: [
          { text: 'Setup', link: '/usage/setup' },
          { text: 'Writing Actions', link: '/usage/writing' },
          { text: 'Using Actions', link: '/usage/using' },
          { text: 'Testing Actions', link: '/usage/testing' },
          { text: 'Conventions', link: '/usage/conventions' },
        ]
      },
      {
        text: 'Reference',
        items: [
          { text: 'Configuration', link: '/reference/configuration' },
          { text: 'Class Interface', link: '/reference/class' },
          { text: 'Instance Interface', link: '/reference/instance' },
          { text: 'Result Interface', link: '/reference/action-result' },
        ]
      },
      {
        text: 'Advanced Usage',
        items: [
          { text: 'ROUGH NOTES', link: '/advanced/rough' },
          { text: 'Validating User Input', link: '/advanced/validating-user-input' },
        ]
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/teamshares/service_action' }
    ]
  }
})
