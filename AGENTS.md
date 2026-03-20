# AI Agent Instructions for kaue Marques Blog

This file provides context and instructions for AI agents working on this repository.

## Project Overview
- **Framework:** Astro
- **Theme:** Astro Cactus
- **Language:** TypeScript
- **Styling:** Tailwind CSS

## Content Structure
- **Posts:** Located in `src/content/post/`.
- **Notes:** Located in `src/content/note/`.
- **Tags:** Located in `src/content/tag/`.
- **Pages:** Located in `src/pages/`.

## Key Configurations
- `src/site.config.ts`: Contains site metadata, menu links, and expressive code options.
- `src/components/SocialList.astro`: Contains social media links.
- `src/components/ThemeProvider.astro`: Manages light/dark mode (defaulted to dark).

## Automated Workflows
- There is a GitHub Action that creates/updates blog posts from GitHub Issues.
- Requirements for the action:
    - Triggered on issue closed (not deleted/cancelled).
    - Updates post if the issue is edited (even if closed).
    - Only processes issues created by the owner (`kaueMarques`).
    - Handles images within the issue body.

## Development Commands
- `npm install`: Install dependencies.
- `npm run dev`: Start local development server.
- `npm run build`: Build for production.
- `npm run postbuild`: Run Pagefind for search indexing.
- `npm run preview`: Preview the production build.

## Coding Standards
- Use TypeScript for all new scripts.
- Prefer functional components in Astro.
- Follow the existing project structure for components and styles.
- When adding new posts, ensure correct frontmatter (title, description, publishDate, tags).
