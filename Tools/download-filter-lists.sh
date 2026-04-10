#!/usr/bin/env bash
#
# download-filter-lists.sh
#
# Downloads well-known hosts-format filter lists, parses them into plain domain
# lists, and outputs JSON arrays suitable for bundling in the Phosphor app.
#
# Usage: ./Tools/download-filter-lists.sh
#
# Output: Phosphor/Resources/BundledLists/*.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/Phosphor/Resources/BundledLists"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

# --- Sources ---
# Ads: Peter Lowe's ad servers list (~3,000 domains)
ADS_URL="https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
# Trackers: EasyPrivacy domains from Firebog (~500 domains)
TRACKERS_URL="https://v.firebog.net/hosts/Easyprivacy.txt"
# Malware: URLhaus abuse.ch active threats (curated, ~2-5K domains)
MALWARE_URL="https://urlhaus.abuse.ch/downloads/hostfile/"
# Adult Content: StevenBlack's porn-only hosts extension
ADULT_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"

# --- Helper: parse hosts file into domain list ---
# Strips comments, removes 0.0.0.0/127.0.0.1 prefix, removes localhost entries,
# lowercases, deduplicates, and sorts.
parse_hosts() {
    local input="$1"
    sed -e 's/#.*$//' \
        -e 's/^0\.0\.0\.0[[:space:]]*//' \
        -e 's/^127\.0\.0\.1[[:space:]]*//' \
        "$input" \
    | tr -d '\r' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -E '^[a-z0-9]' \
    | grep -v '^localhost' \
    | awk '{print $1}' \
    | sort -u
}

# --- Helper: parse plain domain list (one per line) ---
parse_domains() {
    local input="$1"
    sed -e 's/#.*$//' "$input" \
    | tr -d '\r' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -E '^[a-z0-9]' \
    | sort -u
}

# --- Helper: convert domain list to JSON array ---
domains_to_json() {
    local input="$1"
    local output="$2"
    # Build JSON array from newline-separated domains
    echo "[" > "$output"
    local first=true
    while IFS= read -r domain; do
        [ -z "$domain" ] && continue
        if [ "$first" = true ]; then
            printf '  "%s"' "$domain" >> "$output"
            first=false
        else
            printf ',\n  "%s"' "$domain" >> "$output"
        fi
    done < "$input"
    echo "" >> "$output"
    echo "]" >> "$output"
}

# --- Download and process each list ---

echo "==> Downloading Ads list (Peter Lowe)..."
curl -sL "$ADS_URL" -o "$TEMP_DIR/ads_raw.txt"
parse_hosts "$TEMP_DIR/ads_raw.txt" > "$TEMP_DIR/ads_domains.txt"
domains_to_json "$TEMP_DIR/ads_domains.txt" "$OUTPUT_DIR/ads.json"
ADS_COUNT=$(wc -l < "$TEMP_DIR/ads_domains.txt" | tr -d ' ')
echo "    $ADS_COUNT domains"

echo "==> Downloading Trackers list (EasyPrivacy domains)..."
curl -sL "$TRACKERS_URL" -o "$TEMP_DIR/trackers_raw.txt"
parse_domains "$TEMP_DIR/trackers_raw.txt" > "$TEMP_DIR/trackers_domains.txt"
domains_to_json "$TEMP_DIR/trackers_domains.txt" "$OUTPUT_DIR/trackers.json"
TRACKERS_COUNT=$(wc -l < "$TEMP_DIR/trackers_domains.txt" | tr -d ' ')
echo "    $TRACKERS_COUNT domains"

echo "==> Downloading Malware list (URLhaus)..."
curl -sL "$MALWARE_URL" -o "$TEMP_DIR/malware_raw.txt"
parse_hosts "$TEMP_DIR/malware_raw.txt" > "$TEMP_DIR/malware_domains.txt"
domains_to_json "$TEMP_DIR/malware_domains.txt" "$OUTPUT_DIR/malware.json"
MALWARE_COUNT=$(wc -l < "$TEMP_DIR/malware_domains.txt" | tr -d ' ')
echo "    $MALWARE_COUNT domains"

echo "==> Downloading Adult Content list (StevenBlack porn-only)..."
curl -sL "$ADULT_URL" -o "$TEMP_DIR/adult_raw.txt"
parse_hosts "$TEMP_DIR/adult_raw.txt" > "$TEMP_DIR/adult_domains.txt"
domains_to_json "$TEMP_DIR/adult_domains.txt" "$OUTPUT_DIR/adult-content.json"
ADULT_COUNT=$(wc -l < "$TEMP_DIR/adult_domains.txt" | tr -d ' ')
echo "    $ADULT_COUNT domains"

echo ""
echo "==> Done. Bundled lists saved to $OUTPUT_DIR/"
echo "    Ads:            $ADS_COUNT domains"
echo "    Trackers:       $TRACKERS_COUNT domains"
echo "    Malware:        $MALWARE_COUNT domains"
echo "    Adult Content:  $ADULT_COUNT domains"
echo "    Total:          $(( ADS_COUNT + TRACKERS_COUNT + MALWARE_COUNT + ADULT_COUNT )) domains"
