#!/usr/bin/env bats

# BATS test suite for validate-photo-links.sh script
# Install BATS: npm install -g bats
# Run tests: bats tests/validate-photo-links.bats

setup() {
    # Create temporary directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR

    # Create test HTML file
    TEST_HTML="$TEST_DIR/test.html"
    export TEST_HTML
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Test: Valid convention name with year
@test "Valid convention URL with year" {
    cat > "$TEST_HTML" << 'EOF'
<a href="https://photo.felle.me/Furries/Cons/midwest-furfest/2023">Photos</a>
EOF

    # This test verifies the URL format is recognized
    output=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[a-zA-Z0-9/_-]*' "$TEST_HTML")
    [[ "$output" == "https://photo.felle.me/Furries/Cons/midwest-furfest/2023" ]]
}

# Test: Valid convention name without year
@test "Valid convention URL without year" {
    cat > "$TEST_HTML" << 'EOF'
<a href="https://photo.felle.me/Furries/Cons/anthrocon">Photos</a>
EOF

    output=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[a-zA-Z0-9/_-]*' "$TEST_HTML")
    [[ "$output" == "https://photo.felle.me/Furries/Cons/anthrocon" ]]
}

# Test: Convention name with hyphens
@test "Convention name with multiple hyphens" {
    cat > "$TEST_HTML" << 'EOF'
<a href="https://photo.felle.me/Furries/Cons/fur-the-more/2023">Photos</a>
EOF

    output=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[a-zA-Z0-9/_-]*' "$TEST_HTML")
    [[ "$output" == "https://photo.felle.me/Furries/Cons/fur-the-more/2023" ]]
}

# Test: Multiple links extraction
@test "Extract multiple photo links" {
    cat > "$TEST_HTML" << 'EOF'
<a href="https://photo.felle.me/Furries/Cons/anthrocon/2023">AC 2023</a>
<a href="https://photo.felle.me/Furries/Cons/midwest-furfest/2023">MFF 2023</a>
EOF

    output=$(grep -o 'https://photo\.felle\.me/Furries/Cons/[a-zA-Z0-9/_-]*' "$TEST_HTML" | sort -u)
    count=$(echo "$output" | wc -l)
    [[ "$count" -eq 2 ]]
}

# Test: URL format validation - valid convention name format
@test "Validate convention name format - valid" {
    name="midwest-furfest"
    if [[ "$name" =~ ^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]]; then
        return 0
    else
        return 1
    fi
}

# Test: URL format validation - invalid convention name (leading hyphen)
@test "Validate convention name format - invalid (leading hyphen)" {
    name="-invalid-name"
    if [[ "$name" =~ ^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]]; then
        return 1  # Should not match
    else
        return 0
    fi
}

# Test: URL format validation - invalid convention name (double hyphen)
@test "Validate convention name format - invalid (double hyphen)" {
    name="invalid--name"
    if [[ "$name" =~ ^[a-zA-Z0-9]+(-[a-zA-Z0-9]+)*$ ]]; then
        return 1  # Should not match
    else
        return 0
    fi
}

# Test: Year validation - valid 4-digit year
@test "Validate year format - valid" {
    year="2023"
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Test: Year validation - invalid (3 digits)
@test "Validate year format - invalid (3 digits)" {
    year="202"
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        return 1  # Should not match
    else
        return 0
    fi
}

# Test: Year validation - invalid (5 digits)
@test "Validate year format - invalid (5 digits)" {
    year="20233"
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        return 1  # Should not match
    else
        return 0
    fi
}

# Test: Year validation - non-numeric
@test "Validate year format - invalid (non-numeric)" {
    year="abcd"
    if [[ "$year" =~ ^[0-9]{4}$ ]]; then
        return 1  # Should not match
    else
        return 0
    fi
}
