# Design system — paper planner

The UI is built around a warm "paper planner" aesthetic: an editorial, calm,
restrained product surface that treats the weekly timetable as a printed
schedule. Product register, Restrained color strategy with deliberate
session-type tints.

## Tokens

All tokens live in [src/index.css](src/index.css). Colors are in OKLCH; every
neutral is warm-tinted toward the brand hue (no `#000`/`#fff`).

### Color

- **Canvas**: `--paper` `oklch(0.985 0.008 83)` is the page surface; `--paper-2`
  is the next step down for hover and zebra rows. `--surface` is the raised
  surface for panels, lists, and the timetable board.
- **Ink**: `--ink` is the primary text color (`oklch(0.27 0.02 60)` — warm dark
  brown-black, never pure black). `--ink-2` for secondary body, `--ink-3` for
  meta and labels, `--ink-4` for hairlines that need to be slightly stronger
  than text gridlines.
- **Lines**: `--line` is the default hairline; `--line-strong` is for borders
  on interactive surfaces (inputs, buttons, focus rings).
- **Accent**: `--accent` is a single confident deep teal
  (`oklch(0.52 0.085 195)`). Used for the primary action, current state,
  focus ring, and the brand mark. `--accent-tint` and `--accent-edge` form a
  paired light-tint pill for badges and tags. The accent stays at ≤10% of any
  surface, per the Restrained strategy.
- **Session tints** (timetable blocks): three muted, paper-toned hues —
  `--lecture-tint` (teal), `--tutorial-tint` (ochre), `--lab-tint` (clay).
  Each has a matching `--*-edge` border and `--*-ink` text color so the
  block reads as solid-tinted on white without needing a side stripe or a
  gradient.
- **Danger**: `--danger`, `--danger-tint`, `--danger-edge` for conflicts and
  destructive actions. Warm red, not neon.

### Dark mode

Dark theme uses the Flutter app's **Midnight** palette
(`buildDarkPalette(neutralHue: 260, accentHue: 265, paperL: 0.16)`), with
web-specific contrast boosts for ink, lines, and surface separation. Tokens
are overridden on `[data-theme="dark"]` in [src/index.css](src/index.css);
light values remain on `:root`.

- **Activation**: `html[data-theme="light"|"dark"]` set by an inline boot script
  in [public/index.html](public/index.html) (prevents flash) and
  [ThemeProvider](src/theme/ThemeProvider.jsx) at runtime.
- **Persistence**: `localStorage` key `cg_color_scheme`. When unset, the app
  follows `prefers-color-scheme`; toggling writes an explicit choice.
- **Toggle**: Navbar moon/sun icon ([ThemeToggle](src/components/ThemeToggle/ThemeToggle.jsx)).
- **Canvas (dark)**: cool violet-black (`--paper` ~`oklch(0.15 0.019 260)`).
  Accent is violet (~265), not the light-mode teal. Lecture blocks follow the
  accent hue; tutorial/lab keep ochre/clay hues.
- **Shared semantic tokens**: `--scrim`, `--focus-ring`, `--btn-primary-fg`,
  `--btn-primary-hover`, `--warn*`, `--surface-overlay*` for modals, focus
  rings, and sticky headers across both themes.

Admin and all public routes consume the same token set; no separate dark
stylesheet.

### Typography

- **Inter** for all UI, body, and data. System fallback stack is included.
- **Fraunces** (serif) for page-level titles only — never for UI labels,
  buttons, or data. Italic faces are used as a quiet emphasis device (e.g.
  "Build your *week*").
- **IBM Plex Mono** for course codes, kerberos IDs, times, slot names, and
  every label that should read as planner metadata. Tabular numerals are
  enabled where stats appear.
- Fixed rem scale (`--fs-12` through `--fs-44`), ratio ~1.2. No fluid clamp
  headings — product UI viewed at consistent DPI doesn't benefit from them.

### Shape & elevation

- Small radii: `--r-sm: 4px` for chips, `--r: 6px` for buttons and inputs,
  `--r-lg: 10px` for large panels and the timetable board.
- One light shadow (`--shadow-card`) for raised surfaces; one slightly
  stronger one (`--shadow-pop`) for popovers and the analytics modal. No
  glassmorphism, no blurred backdrops as default.

### Motion

- 120ms (`--t-fast`) for color/border transitions on small controls.
- 180ms (`--t`) for hover lifts and panel transitions.
- Single curve, `--ease-out` (`cubic-bezier(0.22, 1, 0.36, 1)`). No bounce.
- Transitions are only on color, opacity, transform, and shadow — never on
  layout properties.

## Shared components

Defined in [src/styles/ui.css](src/styles/ui.css) and used by every page.

- `.btn`, with modifiers `--primary`, `--ghost`, `--danger-ghost`, `--sm`,
  `--lg`, `--icon`. Buttons all share one shape vocabulary — same height,
  same radius, same hover behaviour.
- `.field` for text inputs and selects, with a `--mono` modifier for code
  fields. Selects render a custom caret using two CSS-drawn triangles so
  they look like the rest of the form (no platform-default arrows).
- `.badge` and `.badge--accent` for chips.
- `.panel`, `.rule`, `.empty`, `.status`, `.dl`, `.table` for layout primitives.
- `.mono`, `.serif`, `.muted`, `.dim`, `.tnum` as utility helpers.

### Layout & native controls

Native `<select>`, `<input type="date">`, and `<input type="time">` render their
option menus **outside** the element box. Any ancestor with `overflow: hidden`
(or `overflow: clip`) can cut the menu off — this is not fixable with ARIA or
focus management alone.

**Rules**

- **Never** put `overflow: hidden` on panel bodies (`*__body`, `.admin__body`) or
  filter toolbars (`*__controls`) that contain native controls.
- Use `border-radius` on the shell; put `overflow-x: auto` only on inner scrollers
  (e.g. `.admin__table-wrap`, `.mycal__grid-scroll` when intentional).
- **Fixed-count dashboards** (admin overview, stat strips with known N items):
  use explicit `repeat(N, minmax(0, 1fr))` in page-scoped CSS — not shared `.dl`
  `repeat(auto-fit, minmax(160px, 1fr))`.
- **Verification:** `npm run check:ui` plus a browser pass on every filter dropdown
  after UI edits (see [AGENTS.md](AGENTS.md) UI design ship gate).

## Surfaces

- **Navbar** ([Navbar.jsx](src/components/Navbar/Navbar.jsx)): solid paper
  bar with hairline bottom, serif wordmark + mono path tag, NavLink active
  states render as a short teal underline.
- **Generator** ([Generator.jsx](src/pages/Generator.jsx)): editorial header
  with eyebrow + serif title + mono stat strip, a clean monospaced search
  input, the auto-fetch panel inlined below the search instead of as a
  modal, and a hairline-separated selected-courses sidebar that becomes a
  stacked list on mobile.
- **Timetable** ([Timetable.css](src/components/Timetable/Timetable.css)):
  the print-schedule centerpiece. Mono time rail, dashed hour gridlines,
  per-day columns separated by hairlines, blocks rendered with solid
  session tints and full borders (no side stripe). Conflicts are marked by
  a warm-red border and a diagonal hatch overlay; the empty state speaks
  to the next action.
- **Course Explorer** ([CourseExplorer.jsx](src/pages/CourseExplorer.jsx)):
  dense, scannable catalog list instead of the previous identical card
  grid. Each row is a six-column grid (code, title, instructor, slot,
  venue, credits) collapsing gracefully on smaller screens.
- **Course Details** ([CourseDetails.jsx](src/pages/CourseDetails.jsx)):
  editorial title block with a mono code chip and credits, definition list
  of facts in mono, donut chart with a muted token palette and a
  Total/count center, hairline students table. The analytics modal is
  legitimately a modal (large pivot) and re-skinned to the paper system.
- **Empty Lecture Halls**
  ([EmptyLectureHalls.jsx](src/pages/EmptyLectureHalls.jsx)): labeled day +
  time controls with a "live" pulsing indicator, a stats strip
  (free/occupied/total), and halls grouped by building prefix with each
  hall rendered as a tinted mono tile.

## Admin surfaces

Web-only panel at `/admin` ([admin.css](src/pages/admin/admin.css)). Product register:
dense grids and tables, not editorial spacing from public pages.

- **Shell:** max-width 960px, tabs flush to `.admin__body` card, same OKLCH tokens as the SPA.
- **Overview metrics:** `.admin__priority` — `grid-template-columns: repeat(4, 1fr)` for inbox counts.
- **Overview health:** `.admin__health .dl` — `repeat(3, 1fr)` for six fixed facts (two even rows).
- **Filters:** `.admin__controls` row with [FormField.jsx](src/components/FormField/FormField.jsx); native `<select>` for long enums (audit actions use `<optgroup>`).
- **Tables:** `.admin__table-wrap` may use `overflow-x: auto`; **`.admin__body` must not use `overflow: hidden`** or select menus clip.
- **Actions:** `.admin__actions--inline` — `.btn.btn--sm` row; at most one `.btn--primary` for the primary inbox link.

Mobile (≤640px): priority grid → 2 columns; health grid → 1 column.

## What we avoid

Direct application of the impeccable shared design laws:

- No `#000`/`#fff`; every neutral is tinted toward the brand hue.
- No gradient-clipped text. The previous indigo→purple→pink hero was the
  most obvious offender; it's gone.
- No glassmorphism or `backdrop-filter: blur` as decoration. The previous
  glass navbar, search bar, and timetable board are now solid surfaces.
- No side-stripe accents on cards or blocks. The timetable block used to
  have a 4px left gradient bar; blocks are now solid-tinted with a full
  hairline edge.
- No default modal-first thinking. The auto-fetch panel inlines under the
  search; only the analytics breakdown (a wide pivot) remains a modal, and
  it earns that treatment.
- No identical card grids. The course explorer is a list, the selected
  courses are list rows, the halls are grouped tiles — each surface
  matches the affordance its content needs.
