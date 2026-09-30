#!/usr/bin/env python3
"""Builds the PIR server's input database from the bundled filter lists.

The app's prefilter and the PIR database have to agree: the prefilter decides which
URLs are sent to the server, and the server gives the final answer. A URL listed only
in the prefilter is looked up and then allowed.

Usage: ./Tools/build-pir-database.py [output.txtpb]

Writes PIRServer/data/url-database.txtpb by default. Process it on the server with
PIRProcessDatabase, see PIRServer/README.md.
"""

import json
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
LISTS = PROJECT / "Phosphor" / "Resources" / "BundledLists"
DEFAULT_OUTPUT = PROJECT / "PIRServer" / "data" / "url-database.txtpb"

# Apple's onboarding looks this URL up to check the deployment. The `www.` form is the
# one Apple names; the bare form is the one a device asks for.
ONBOARDING_TEST_ENTRIES = ["www.apple.com/url-filter-test", "apple.com/url-filter-test"]


def normalized(url: str) -> str:
    """The form a device looks up: lowercased, without a leading `www.`."""
    url = url.lower()
    return url[4:] if url.startswith("www.") else url


def main() -> None:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    manifest = json.loads((LISTS / "bundled-lists.json").read_text())

    keywords = set(ONBOARDING_TEST_ENTRIES)
    for entry in manifest:
        hosts = json.loads((LISTS / entry["filename"]).read_text())
        keywords.update(normalized(host) for host in hosts)
        print(f"{entry['name']}: {len(hosts)} entries")

    for keyword in keywords:
        if '"' in keyword or "\\" in keyword or "\n" in keyword:
            sys.exit(f"Entry cannot be written to the database: {keyword!r}")

    with output.open("w") as file:
        for keyword in sorted(keywords):
            file.write(f'rows {{ keyword: "{keyword}" value: "1" }}\n')
    print(f"Wrote {len(keywords)} keywords to {output}")


if __name__ == "__main__":
    main()
