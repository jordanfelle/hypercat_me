# Responsive Images with Lazy Loading

This site now includes automatic responsive image generation with lazy loading support.

## Usage

Use the `img` shortcode in your markdown files:

```markdown
{{< img src="images/my-photo.jpg" alt="Description of the image" >}}
```

### Parameters

- `src` (required): Path to the image in the `assets/` directory
- `alt` (required): Alt text for accessibility
- `title` (optional): Image title attribute
- `class` (optional): Additional CSS classes
- `width` (optional): Explicit width for aspect ratio
- `height` (optional): Explicit height for aspect ratio

### Examples

Basic usage:

```markdown
{{< img src="images/profile.jpg" alt="My profile picture" >}}
```

With additional options:

```markdown
{{< img src="images/banner.jpg" alt="Site banner" title="Welcome!" class="hero-image" >}}
```

With explicit dimensions:

```markdown
{{< img src="images/photo.jpg" alt="Event photo" width="1920" height="1080" >}}
```

## Features

- **Automatic responsive sizes**: Generates 480px, 800px, and 1200px versions
- **Lazy loading**: Images load as they come into view
- **Srcset support**: Browser automatically selects the best size
- **Aspect ratio preservation**: Prevents layout shift during load
- **Fade-in animation**: Smooth loading transition
- **SEO friendly**: Proper alt text and dimensions

## Technical Details

The shortcode automatically:

1. Processes images from the `assets/` directory
2. Generates multiple sizes using Hugo's image processing
3. Creates a srcset with appropriate breakpoints
4. Adds lazy loading and async decoding
5. Preserves aspect ratio to prevent CLS
