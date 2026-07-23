#!/usr/bin/env python3
"""Extract course → venues map from room allotment PDF. Prints JSON to stdout."""

import argparse
import json
import os
import re
import ssl
import sys
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone

try:
    from pypdf import PdfReader
except ImportError:
    try:
        from PyPDF2 import PdfReader
    except ImportError:
        print("Error: install pypdf or PyPDF2 (e.g. pacman -S python-pypdf).", file=sys.stderr)
        sys.exit(1)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PDF_URL = os.environ.get(
    'ROOM_ALLOTMENT_PDF_URL',
    'https://roombooking.iitd.ac.in/allot/files/Room_Allotment_Chart.pdf',
)
LOCAL_PDF_PATH = os.path.join(SCRIPT_DIR, '../data/Room_Allotment_Chart.pdf')
SOURCE_PDF_NAME = os.path.basename(PDF_URL)
SOURCE_SEMESTER = os.environ.get('ROOM_ALLOTMENT_SOURCE_SEMESTER', '2601')

COURSE_REGEX = r"\b([A-Z]{3}\d{3,4}[A-Z]?)\b"
VENUE_PATTERNS = [
    r"LH\s?\d{3}(\.\d+)?",
    r"[IV]{1,3}\s?LT\s?\d",
    r"[IV]{1,3}\s?\d{3}",
    r"IIA\s?\d{3}",
    r"\bDH\b",
]
VENUE_REGEX = r"(" + "|".join(VENUE_PATTERNS) + r")"


def normalize_venue(v):
    if not v:
        return None
    s = " ".join(v.split())
    lh = re.match(r"^LH\s*(.+)$", s, re.I)
    if lh:
        return f"LH {lh.group(1).strip()}"
    return s


def parse_pdf(pdf_path):
    pdf_courses = defaultdict(set)
    with open(pdf_path, 'rb') as f:
        reader = PdfReader(f)
        for page in reader.pages:
            text = page.extract_text()
            if not text:
                continue
            current_venue = None
            buffer_courses = []
            for line in text.split('\n'):
                if line.startswith("Room") and ("8-9" in line or "Day" in line):
                    current_venue = None
                    buffer_courses = []
                    continue
                venue_match = re.search(VENUE_REGEX, line)
                line_courses = re.findall(COURSE_REGEX, line)
                valid_courses = [c for c in line_courses if not re.fullmatch(VENUE_REGEX, c)]
                if venue_match:
                    current_venue = normalize_venue(venue_match.group(0))
                    for bc in buffer_courses:
                        pdf_courses[bc].add(current_venue)
                    buffer_courses = []
                    for c in valid_courses:
                        pdf_courses[c].add(current_venue)
                elif current_venue:
                    for c in valid_courses:
                        pdf_courses[c].add(current_venue)
                else:
                    buffer_courses.extend(valid_courses)
    return {k: sorted(v) for k, v in pdf_courses.items()}


def expand_section_venues(pdf_courses):
    """Fold section-letter codes into base (CVL100A/B → CVL100)."""
    out = defaultdict(set)
    section_re = re.compile(r"^([A-Z]+\d+)[A-Z]$")
    for code, venues in pdf_courses.items():
        out[code].update(venues)
        m = section_re.match(code)
        if m:
            out[m.group(1)].update(venues)
    return {k: sorted(v) for k, v in out.items()}


def unique_rooms(pdf_courses):
    rooms = set()
    for venues in pdf_courses.values():
        for v in venues:
            n = normalize_venue(v)
            if n:
                rooms.add(n)
    return sorted(rooms, key=_room_sort_key)


def _room_sort_key(name):
    prefix = re.match(r"^(\w+)", name)
    p = prefix.group(1) if prefix else "Other"
    nums = re.findall(r"[\d.]+", name)
    num = float(nums[0]) if nums else 0.0
    return (p, num, name)


def download_pdf(url, local_path):
    context = ssl._create_unverified_context()
    with urllib.request.urlopen(url, context=context) as response, open(local_path, 'wb') as out:
        out.write(response.read())


def ensure_pdf(pdf_path):
    if not os.path.exists(pdf_path):
        try:
            download_pdf(PDF_URL, pdf_path)
        except Exception as e:
            print(f"PDF download failed: {e}", file=sys.stderr)
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Extract venues from room allotment PDF")
    parser.add_argument(
        '--rooms-list',
        action='store_true',
        help='Emit unique campus room names (for client fallback list)',
    )
    args = parser.parse_args()

    pdf_path = LOCAL_PDF_PATH
    ensure_pdf(pdf_path)
    data = parse_pdf(pdf_path)
    # Keep raw keys for rooms-list; fold A/B sections for course→venue map.
    course_map = expand_section_venues(data)

    if args.rooms_list:
        payload = {
            'sourcePdf': SOURCE_PDF_NAME,
            'sourceSemester': SOURCE_SEMESTER,
            'generatedAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'rooms': unique_rooms(data),
        }
        json.dump(payload, sys.stdout, indent=2)
        sys.stdout.write('\n')
    else:
        json.dump(course_map, sys.stdout)


if __name__ == '__main__':
    main()
