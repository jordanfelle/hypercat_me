# hypercat_me

This is the source repository for the **hypercat_me** website, a static site built with [Hugo](https://gohugo.io/) using the [PaperMod theme](themes/hugo-PaperMod/README.md).

## Features

- Powered by [Hugo](https://gohugo.io/) for fast static site generation
- Uses the [PaperMod theme](themes/hugo-PaperMod/README.md) for a clean, responsive design
- Organized content under `/content`
- Image assets in `/assets/images`
- Custom archetypes for easy content creation
- Automated image optimization via GitHub Actions

## Getting Started

1. **Install Hugo**  
   Make sure you have [Hugo](https://gohugo.io/getting-started/installing/) (version 0.146.0 or higher) installed.

2. **Clone the repository**

   ```sh
   git clone --recurse-submodules https://github.com/yourusername/hypercat_me.git
   cd hypercat_me
   ```

3. **Run the development server**
   ```sh
   hugo server
   ```
   Visit `http://localhost:1313` to view the site locally.

## Content Structure

- `content/` — Main site content (Markdown files)
- `assets/images/` — Image assets
- `themes/hugo-PaperMod/` — Hugo PaperMod theme (as a submodule)
- `archetypes/` — Archetypes for new content

## Deployment

Build the site with:

```sh
hugo
```

The generated static files will be in the `public/` directory.

## License

- Site content: [Specify your license here]
- Theme: MIT License (see themes/hugo-PaperMod/)

## Credits

- [Hugo](https://gohugo.io/)
- [PaperMod Theme](https://github.com/adityatelange/hugo-PaperMod)
