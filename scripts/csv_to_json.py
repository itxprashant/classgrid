
import csv
import json
import re
import sys
import os

INPUT_CSV = os.path.join(os.path.dirname(__file__), '../data/Courses_Offered.csv')
OUTPUT_JSON = os.path.join(os.path.dirname(__file__), '../src/courses.json')

def parse_credit_structure(units_str):
    # Format: L-T-P e.g. "3.0-0.0-2.0"
    try:
        parts = [float(x) for x in units_str.split('-')]
        if len(parts) == 3:
            return parts, parts[0] + parts[1] + 0.5 * parts[2]
    except:
        pass
    return [0, 0, 0], 0

def clean_course_code(name_str):
    # "MINOR PROJECT-AMD5050" -> "AMD5050"
    # "MAJOR PROJECT PART-II-AMD812" -> "AMD812"
    # Sometimes names might not have hyphens? 
    if not name_str: return ""
    parts = name_str.rsplit('-', 1)
    if len(parts) > 1:
        return parts[-1].strip()
    return name_str.strip()

# Days mapping: Th is checked before T
# Days mapping: Th is checked before T
DAYS_MAP = {
    'M': '1',
    'T': '2',
    'W': '3',
    'Th': '4',
    'F': '5',
    'S': '6',
    'Su': '7'
}

def parse_timings(time_str):
    """
    Parses strings like "MTh 09:30-11:00" -> "109301100,409301100"
    Returns a comma-separated string of timing codes or None.
    """
    if not time_str: return None
    
    encoded_timings = []
    # Split by comma for multiple distinct slots
    parts = time_str.split(',')
    
    for part in parts:
        part = part.strip()
        if not part: continue
        
        # Regex to separate days from time range
        # Matches "MTh 09:30-11:00"
        match = re.search(r'([A-Za-z]+)\s+(\d{1,2}:\d{2})-(\d{1,2}:\d{2})', part)
        if match:
            days_str = match.group(1)
            start_time = match.group(2)
            end_time = match.group(3)
            
            # Parse days. Tokenize greedy 'Th' then single chars
            i = 0
            parsed_days = []
            while i < len(days_str):
                if i + 1 < len(days_str) and days_str[i:i+2] == 'Th':
                    parsed_days.append('Th')
                    i += 2
                else:
                    parsed_days.append(days_str[i])
                    i += 1
            
            # Format times to HHMM (ensure 4 chars)
            def fmt_time_code(t):
                h, m = t.split(':')
                return f"{int(h):02d}{m}"
                
            st_code = fmt_time_code(start_time)
            et_code = fmt_time_code(end_time)
            
            for d in parsed_days:
                if d in DAYS_MAP:
                    # Format: DHHMMHHMM
                    day_code = DAYS_MAP[d]
                    code_str = f"{day_code}{st_code}{et_code}"
                    encoded_timings.append(code_str)
                    
    if not encoded_timings:
        return None
        
    return ",".join(encoded_timings)

def extract_course_name(name_str):
    # "MINOR PROJECT-AMD5050" -> "MINOR PROJECT"
    if not name_str: return ""
    parts = name_str.rsplit('-', 1)
    if len(parts) > 1:
        return parts[0].strip()
    return name_str.strip()

def main():
    if not os.path.exists(INPUT_CSV):
        print(f"Error: {INPUT_CSV} not found.")
        return

    courses = []
    
    with open(INPUT_CSV, 'r', encoding='utf-8', errors='replace') as f:
        reader = csv.reader(f)
        
        for row_idx, row in enumerate(reader):
            if not row: continue
            
            # 1. Identify valid data row (S.No at 0 is digit)
            s_no = row[0].strip()
            if not s_no.isdigit():
                continue
            
            raw_course_name = row[1].strip()
            
            # 2. Find Units Column (Format: d-d-d or d.d-d.d-d.d)
            units_idx = -1
            for i, col in enumerate(row):
                if re.match(r'^\d+(\.\d+)?-\d+(\.\d+)?-\d+(\.\d+)?$', col.strip()):
                    units_idx = i
                    break
            
            if units_idx == -1:
                # Fallback: assume index 5 if not found (standard)
                units_idx = 5 if len(row) > 5 else -1
            
            if units_idx != -1:
                units = row[units_idx].strip()
            else:
                units = "0-0-0"
                
            # 3. Find Email Column (contains @)
            email_idx = -1
            # Search after units
            start_search = units_idx + 1 if units_idx != -1 else 2
            for i in range(start_search, len(row)):
                if '@' in row[i]:
                    email_idx = i
                    break
            
            # 4. Identify Time Columns
            # Standard: Email(9), Lex(10), Tut(11), Sep(12), Prac(13), Sep(14), Vacancy(15)
            # Compressed: Email(7), Lex(8), Tut(9), Prac(10), Vacancy(11)
            
            lecture_str = ""
            tutorial_str = ""
            practical_str = ""
            
            if email_idx != -1:
                # Anchor based on Email
                # Vacancy is usually at row[-2]
                vacancy_idx = len(row) - 2
                
                # Check if we have valid columns between Email and Vacancy
                # Timings start at email_idx + 1
                if vacancy_idx > email_idx + 1:
                    timing_cols = row[email_idx+1 : vacancy_idx]
                    
                    # Logic to map timing_cols to L, T, P
                    # If 5 cols: [L, T, Sep, P, Sep] (Standard)
                    # If 3 cols: [L, T, P] (Compressed)
                    # If 4 cols: [L, T, Sep, P] ?
                    
                    if len(timing_cols) >= 1:
                        lecture_str = timing_cols[0].strip()
                    
                    if len(timing_cols) >= 2:
                        tutorial_str = timing_cols[1].strip()
                        
                    if len(timing_cols) >= 3:
                        if len(timing_cols) == 3:
                            practical_str = timing_cols[2].strip()
                        elif len(timing_cols) >= 4:
                            # Skip index 2 (separator) -> index 3 is practical
                            practical_str = timing_cols[3].strip()
            else:
                # No email found. Fallback to fixed offsets from Units if we found Units?
                # Standard: Units(5) -> Lex(10) (diff +5)
                # Compressed: Units(4) -> Lex(8) (diff +4)
                # This is risky. Let's just try standard offset if Units is 5
                if units_idx == 5 and len(row) > 13:
                     lecture_str = row[10].strip()
                     tutorial_str = row[11].strip()
                     practical_str = row[13].strip()
                elif units_idx == 4 and len(row) > 8:
                     # Row 12 case: Units(4), Lex(8)
                     lecture_str = row[8].strip()
                     if len(row) > 9: tutorial_str = row[9].strip()
                     if len(row) > 10: practical_str = row[10].strip()

            code = clean_course_code(raw_course_name)
            name = extract_course_name(raw_course_name)
            if not code: continue
            
            # Slot is usually index 3, but let's check relative to Units
            # Standard: Slot(3), Units(5) -> Units-2
            # Compressed: Slot(3), Units(4) -> Units-1
            # Let's verify content of index 3
            slot_name = "X"
            if len(row) > 3:
                 candidate = row[3].strip()
                 if len(candidate) <= 2: # "A", "B", "AA"
                     slot_name = candidate
            
            # If Slot wasn't found at 3, try Units-1 or Units-2
            if slot_name == "X" and units_idx != -1:
                 if units_idx - 1 >= 0 and len(row[units_idx-1].strip()) <= 2 and row[units_idx-1].strip():
                     slot_name = row[units_idx-1].strip()
                 elif units_idx - 2 >= 0 and len(row[units_idx-2].strip()) <= 2 and row[units_idx-2].strip():
                     slot_name = row[units_idx-2].strip()

            _, total_credits = parse_credit_structure(units)
            
            # Extract Instructor (Column before Email)
            instructor = "N/A"
            if email_idx != -1 and email_idx > 0:
                instructor = row[email_idx-1].strip()
            
            # Extract Current Strength (Last column usually)
            current_strength = "N/A"
            # It seems Current Strength is the last column
            if len(row) > 0:
                current_strength = row[-1].strip()

            course_obj = {
                "courseCode": code,
                "courseName": name,
                "semesterCode": "2502",
                "totalCredits": total_credits,
                "creditStructure": units,
                "instructor": instructor,
                "currentStrength": current_strength,
                "slot": {
                    "name": slot_name if slot_name else "X",
                    "lectureTiming": parse_timings(lecture_str),
                    "lectureTimingStr": lecture_str,
                    "tutorialTiming": None,
                    "labTiming": None
                },
                "lectureHall": None
            }
            
            courses.append(course_obj)

    print(f"Parsed {len(courses)} courses.")
    
    with open(OUTPUT_JSON, 'w') as f:
        json.dump(courses, f, indent=2)
    
    print(f"Written to {OUTPUT_JSON}")

if __name__ == "__main__":
    main()
