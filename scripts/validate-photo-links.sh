#!/bin/bash

# Validation script for photo.felle.me links in cons page

echo "Validating photo.felle.me links..."

CONS_HTML="public/cons/index.html"
ERRORS=0

if [ ! -f "$CONS_HTML" ]; then
    echo "Error: $CONS_HTML not found. Please run 'hugo' first."
    exit 1
fi

# Extract all photo.felle.me URLs
LINKS=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[^"]*' "$CONS_HTML" | sort -u)

echo "Found links:"
while IFS= read -r link; do
    # Check URL format: https://photo.felle.me/Furries/Cons/{ConventionName}[/{Year}]

    # Remove the base URL
    path="${link#https://photo.felle.me/Furries/Cons/}"

    # Check if path is empty
    if [ -z "$path" ]; then
        echo "❌ Empty convention name in: $link"
        ((ERRORS++))
        continue
    fi

    # Split path into convention name and year (if present)
    IFS='/' read -r conv_name year <<< "$path"

    # Validate convention name (should have hyphens and letters)
    if ! [[ "$conv_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "❌ Invalid convention name format: $conv_name in $link"
        ((ERRORS++))
        continue
    fi

    # If year is present, validate it's a 4-digit number
    if [ -n "$year" ]; then
        if ! [[ "$year" =~ ^[0-9]{4}$ ]]; then
            echo "❌ Invalid year format: $year in $link"
            ((ERRORS++))
            continue
        fi
        echo "✓ Valid: $conv_name / $year"
    else
        echo "✓ Valid: $conv_name (directory)"
    fi
done <<< "$LINKS"

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All photo links are valid!"
    exit 0
else
    echo "❌ Found $ERRORS validation errors"
    exit 1
fi
