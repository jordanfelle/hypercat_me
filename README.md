# hypercat_me

This is the source repository for the **hypercat_me** website, a static site built with [Hugo](https://gohugo.io/) using a custom theme based on [PaperMod](https://github.com/adityatelange/hugo-PaperMod).

## Features

- Powered by [Hugo](https://gohugo.io/) for fast static site generation
- Custom Hugo theme with clean, responsive design
- Organized content under `/content`
- Image assets in `/assets/images`
- Custom archetypes for easy content creation
- Automated image optimization via GitHub Actions
- Convention schedule tracking with upcoming and past conventions support
- Staff tracking for conventions

## Getting Started

1. **Install Hugo**  
   Make sure you have [Hugo](https://gohugo.io/getting-started/installing/) (version 0.146.0 or higher) installed.

2. **Clone the repository**

   ```sh
   git clone https://github.com/yourusername/hypercat_me.git
   cd hypercat_me
   ```

3. **Run the development server**
   ```sh
   hugo server
   ```
   Visit `http://localhost:1313` to view the site locally.

## Content Structure

- `content/` — Main site content (Markdown files)
  - `sona/` — Character/persona content
  - `cons/` — Convention schedule entries
- `assets/images/` — Image assets
- `assets/css/extended/` — Custom CSS extensions
- `themes/hypercat-theme/` — Custom Hugo theme
- `archetypes/` — Archetypes for new content

## Deployment

Build the site with:

```sh
hugo
```

The generated static files will be in the `public/` directory.

## Convention Schedule

The site includes a custom convention schedule page at `/cons/` that displays upcoming and past conventions.

### Adding a Convention

Create a new file in `content/cons/` with the following front matter:

```yaml
---
title: "Convention Name"
month: "July"              # Month name (e.g., "July", "December")
location: "City, State, Country"
attendeeYears: "2024, 2025, 2026"  # Comma-separated list of years attended
staffYears: "2025, 2026"            # (Optional) Years you staffed the convention
---
```

**Front Matter Parameters:**
- `title` (required): Convention name
- `month` (required): Month in format "MonthName" (e.g., "July") or "MonthName Year" (e.g., "July 2026") or "YYYY-MM"
- `location` (required): Convention location
- `attendeeYears`: Comma-separated list of years attended
- `staffYears` (optional): Comma-separated list of years staffed

**Display Logic:**
- Conventions are automatically sorted chronologically
- Upcoming conventions show only the year (or "Staff: year" if staffing)
- Past conventions display attended years and staffed years separately with a "Staff: year" badge
- Only years >= the convention's year appear for staffing in the upcoming section

## License

- Site content: [Specify your license here]
- Theme: MIT License (see themes/hugo-PaperMod/)

## Credits

- [Hugo](https://gohugo.io/)
- [PaperMod Theme](https://github.com/adityatelange/hugo-PaperMod) (original theme this is based on)
