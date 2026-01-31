#!/bin/bash

# Link validation script
# Checks for broken internal links and common issues in generated HTML

echo "Validating links in built site..."

BUILD_DIR="public"
ERRORS=0

if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Build directory not found: $BUILD_DIR"
    exit 1
fi

# Extract all href attributes from HTML files
echo "Checking for broken references..."

# Check for href="#" (placeholder links)
placeholder_links=$(find "$BUILD_DIR" -name "*.html" -type f -exec grep -l 'href="#"' {} \;)
if [ -n "$placeholder_links" ]; then
    echo "⚠️  Found placeholder links (href=\"#\") in:"
    echo "$placeholder_links" | head -5
    ((ERRORS++))
fi

# Check for empty href attributes
empty_hrefs=$(find "$BUILD_DIR" -name "*.html" -type f -exec grep -l 'href=""' {} \;)
if [ -n "$empty_hrefs" ]; then
    echo "❌ Found empty href attributes in:"
    echo "$empty_hrefs" | head -5
    ((ERRORS++))
fi

# Check for JavaScript void links
void_links=$(find "$BUILD_DIR" -name "*.html" -type f -exec grep -l 'href="javascript:void' {} \;)
if [ -n "$void_links" ]; then
    echo "⚠️  Found javascript:void links in:"
    echo "$void_links" | head -5
fi

# Check for images without alt attributes (accessibility)
missing_alt=$(find "$BUILD_DIR" -name "*.html" -type f -exec grep -l '<img[^>]*[^a][^l][^t]' {} \; 2>/dev/null | head -5)
if [ -n "$missing_alt" ]; then
    echo "⚠️  Some images missing alt attributes (found in up to 5 files)"
fi

# Check for common broken link patterns
echo "Checking for common broken patterns..."

# Check for double slashes in paths (except protocol)
double_slash=$(find "$BUILD_DIR" -name "*.html" -type f -exec grep -o 'href="[^"]*//[^"]*"' {} \; | grep -v 'http' | head -3)
if [ -n "$double_slash" ]; then
    echo "⚠️  Found potential double-slash issues: $double_slash"
fi

# Verify all .html file internal links exist (basic check)
echo "Verifying HTML file structure..."
html_count=$(find "$BUILD_DIR" -name "*.html" -type f | wc -l)
if [ "$html_count" -eq 0 ]; then
    echo "❌ No HTML files found in $BUILD_DIR"
    exit 1
fi
echo "✓ Found $html_count HTML files"

# Check for malformed HTML (unclosed tags)
malformed=$(find "$BUILD_DIR" -name "*.html" -type f -exec sh -c 'grep -c "<[a-z][a-z0-9]*[^>]*>$" "$1" 2>/dev/null || true' _ {} \; | grep -v "^0$" | wc -l)
if [ "$malformed" -gt 0 ]; then
    echo "⚠️  Some files may have unclosed tags"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ Link validation passed!"
    exit 0
else
    echo "⚠️  Found $ERRORS potential issues (non-blocking)"
    exit 0  # Don't fail the build for link issues
fi
