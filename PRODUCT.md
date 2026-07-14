# Product

## Register

product

## Users

IIT Delhi students, on laptops during registration week and on phones between
classes. They are picking courses under time pressure, checking for slot
clashes, finding an empty lecture hall right now, or checking when the next
quiz is. A small group of student admins uses `/admin` to triage feedback,
reports, and push notifications. Guests can plan without logging in; IITD
OAuth unlocks sync, rosters, and calendars.

## Product Purpose

ClassGrid turns the institute's raw course catalog into a personal weekly
planner: build a clash-free timetable, explore every course/professor/student
on record, find free rooms at any date and time, and keep a shared course
calendar (quizzes, deadlines) plus private events. Success looks like students
reaching for ClassGrid instead of the official ERP or a shared spreadsheet,
and trusting what it shows enough to plan their semester on it.

## Brand Personality

Warm, personal, characterful. The feel of a well-kept paper notebook that is
unmistakably *yours* — not a sterile SaaS dashboard and not a government
portal. Three words: **warm, crafted, trustworthy**. The current identity
(restrained "paper planner") is the base; the ambition is more character and
quiet delight without losing calm: personality carried by typography, texture,
color voice, and copy — never by gimmicks that slow a student down during
registration week.

## Anti-references

- The official IITD ERP / eAcademics aesthetic: dated tables, no hierarchy,
  hostile to phones.
- Generic AI-SaaS defaults: cream-on-cream cards, gradient-clipped hero text,
  glassmorphism, identical icon-card grids, hero-metric strips.
- Cold enterprise admin suites (dense chrome, gray-on-gray, zero voice).
- Over-animated portfolio sites; students are here mid-task, not to watch
  choreography.

## Design Principles

1. **The timetable is the hero.** Every surface exists to make schedule
   comprehension instant; decoration never competes with the grid.
2. **Earned familiarity.** Standard affordances, one component vocabulary
   across every page (public and admin). Surprise is spent on moments, not
   controls.
3. **Warmth through craft, not decoration.** Character comes from type
   pairing, texture, color voice, and human copy — not stripes, glass, or
   gradients.
4. **Dense where students work, calm where they read.** Planner, rooms, and
   admin earn density; course details and calendars earn editorial air.
5. **Both themes are first-class.** Light and dark get equal contrast,
   equal polish; no dark-mode afterthoughts.

## Accessibility & Inclusion

- Target **WCAG 2.1 AA**: body text ≥4.5:1, large text ≥3:1, visible focus
  states on every interactive element.
- Full keyboard support on interactive rows (selectable table rows already
  use `adminSelectableRow.js`; hold new surfaces to the same bar).
- `prefers-reduced-motion` honored on every animation.
- Color is never the only channel for meaning (clash hatch pattern on the
  timetable, badges carry text, not just tint).
