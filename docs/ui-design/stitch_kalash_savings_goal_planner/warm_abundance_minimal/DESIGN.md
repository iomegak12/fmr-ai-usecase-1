---
name: Warm Abundance Minimal
colors:
  surface: '#fff8f1'
  surface-dim: '#dfd9d1'
  surface-bright: '#fff8f1'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f9f3eb'
  surface-container: '#f4ede5'
  surface-container-high: '#eee7df'
  surface-container-highest: '#e8e1da'
  on-surface: '#1e1b17'
  on-surface-variant: '#544338'
  inverse-surface: '#33302b'
  inverse-on-surface: '#f7f0e8'
  outline: '#877367'
  outline-variant: '#dac2b3'
  surface-tint: '#954a00'
  primary: '#924800'
  on-primary: '#ffffff'
  primary-container: '#b25f18'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb786'
  secondary: '#5b598c'
  on-secondary: '#ffffff'
  secondary-container: '#c7c3fe'
  on-secondary-container: '#514f81'
  tertiary: '#186a22'
  on-tertiary: '#ffffff'
  tertiary-container: '#358438'
  on-tertiary-container: '#f7fff1'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdcc6'
  primary-fixed-dim: '#ffb786'
  on-primary-fixed: '#311400'
  on-primary-fixed-variant: '#723600'
  secondary-fixed: '#e3dfff'
  secondary-fixed-dim: '#c4c1fb'
  on-secondary-fixed: '#181445'
  on-secondary-fixed-variant: '#444173'
  tertiary-fixed: '#a3f69c'
  tertiary-fixed-dim: '#88d982'
  on-tertiary-fixed: '#002204'
  on-tertiary-fixed-variant: '#005312'
  background: '#fff8f1'
  on-background: '#1e1b17'
  surface-variant: '#e8e1da'
typography:
  display:
    fontFamily: Epilogue
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  display-mobile:
    fontFamily: Epilogue
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Epilogue
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Epilogue
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Epilogue
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-sm:
    fontFamily: Epilogue
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  label-lg:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
  currency-display:
    fontFamily: Inter
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
    letterSpacing: -0.02em
  currency-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-tablet: 1.5rem
  gutter-desktop: 2rem
  margin: 1rem
  margin-tablet: 2rem
  margin-desktop: 4rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style
The design system embodies the ritual of steady accumulation, grounded in the cultural metaphor of a vessel being filled to the brim. It speaks directly to Gen Z and young Indian professionals navigating personal finance by rejecting the sterile, clinical tropes of legacy banking in favor of warmth, grounded optimism, and calm authority.

The aesthetic blends **Modern Minimalist Fintech** with subtle, organic warmth. It relies on generous breathing room, structured clarity, and soft tactile elevation. Interactions should feel deliberate, quiet, and satisfying—celebrating micro-milestones without loud gamification or visual clutter. The goal is to evoke quiet confidence, stability, and thoughtful discipline.

## Colors
The palette balances warm earthiness with deep financial authority. 

- **Primary (`#C8702A` Warm Copper):** Used for focal calls-to-action, fill indicators, progress highlights, and interactive accents. It echoes fired clay and polished brass.
- **Secondary (`#1E1B4B` Deep Indigo):** Provides structural weight. Applied to high-emphasis typography, primary container surfaces, and key navigation states.
- **Background (`#FFF8F0` Soft Cream):** Replaces pure digital white as the global canvas, reducing harsh glare and setting an inviting, tactile baseline.
- **Surface (`#FFFFFF` Pure White):** Reserved for elevated cards, modals, and sheets to provide distinct separation against the cream backdrop.
- **Semantic / Status System:**
  - **Active:** `#1E1B4B` (Deep Indigo)
  - **Achieved:** `#2E7D32` (Forest Green)
  - **Off-track:** `#F59E0B` (Warm Amber)
  - **Overdue:** `#D32F2F` (Crimson)
  - **Cancelled / Dormant:** `#9E9E9E` (Muted Grey)
  - **Neutral Subdued Text:** `#64748B` (Slate Muted)
  - **Border / Divider:** `#EADDCF` (Warm Oat Line)

## Typography
Epilogue provides geometric structure with distinctive architectural presence for editorial titles and goal names. Inter handles body paragraphs, microcopy, and numerical readouts, offering high legibility and standard tabular figures.

### Numeric & Currency Formatting Rules
- **Symbol:** Indian Rupee (`₹`) precedes numbers with zero kerning gap.
- **Grouping:** Follow the Indian numbering system strictly: thousands, followed by lakhs and crores (e.g., `₹1,20,000`, `₹15,00,000`). Display whole values without paisa decimals.
- **Percentages:** Precision is locked to one decimal place across all tracking badges and progression curves (e.g., `24.0%`, `99.5%`).

## Layout & Spacing
The layout follows a fluid-responsive structure anchored by a 4-column system on mobile, 8-column on tablet, and 12-column on desktop. 

- **Vertical Rhythm:** Rooted in an 8px base grid (`0.5rem`). Components use generous internal paddings to maintain an unhurried, spacious demeanor.
- **Mobile Hand-Zone:** Goal actions, quick-deposit keys, and primary navigation remain locked in safe bottom areas with `margin: 1rem` breathing bounds.
- **Max Canvas Width:** Core application dashboards restrict content spanning to `1120px` centered width on desktop screens to avoid diluted progress tracking views.

## Elevation & Depth
Elevation is conveyed using warm ambient diffusion rather than cold grey drop shadows. Surfaces appear lightly suspended over the `#FFF8F0` canvas.

- **Level 0 (Flat):** Neutral canvas layer. No shadow.
- **Level 1 (Cards, Rest State):** Single ambient shadow: `0 4px 20px -2px rgba(30, 27, 75, 0.04)`, combined with a subtle border of `1px solid #EADDCF`.
- **Level 2 (Hover / Active Cards / Menus):** `0 8px 24px -4px rgba(200, 112, 42, 0.08), 0 2px 6px -1px rgba(30, 27, 75, 0.04)`.
- **Level 3 (Modals / Bottom Sheets):** `0 16px 40px -8px rgba(30, 27, 75, 0.16)`. Accompanied by a 30% deep indigo frosted backdrop blur (`rgba(30, 27, 75, 0.3)` with `backdrop-filter: blur(4px)`).

## Shapes
A consistent radius of 12px to 16px (`rounded-lg` to `rounded-xl`) defines container geometry, giving visual reference to handcrafted, smooth earthenware pots. 

- **Buttons & Action Inputs:** Standardized at 12px (`0.75rem`) border radius for balanced touch feedback.
- **Cards & Modal Containers:** Locked between 14px and 16px (`1rem`) to soften structural edges.
- **Pills / Status Chips:** Fully rounded circular caps (`9999px`) to create clear differentiation against rectilinear content blocks.
- **Progress Trackers:** Capsule runners with fully pill-shaped terminal caps to signify fluid accumulation.

## Components

### Buttons
- **Primary:** Filled `#C8702A` with `#FFFFFF` text. Height `48px` (touch target). Micro-radius `12px`. Hover shifts to `#B36020`. Active scales down smoothly by 1% (`scale: 0.99`).
- **Secondary:** Transparent fill with `1.5px solid #1E1B4B`, text `#1E1B4B`.
- **Subtle / Ghost:** Soft Cream hover fill (`#F5E8D8`) with Warm Copper typography.

### Goal Cards ("Kalash" Vessels)
- White `#FFFFFF` surface with `16px` border radius and `Level 1` ambient elevation.
- Internal padding `20px` (`1.25rem`).
- Header displays Goal Title (`Epilogue` 18px, `#1E1B4B`) paired with a Pill Status Chip.
- Progress bar embedded as a track in `#F5E8D8` with dynamic fill in `#C8702A`.
- Metric row: Current saved amount (`₹1,20,000`) anchored beside total percentage (`24.0%`).

### Chips & Status Badges
- Height `24px`, fully rounded (`9999px`), padding `0 10px`.
- Inter font, 11px, weight 600, uppercase letter-spacing +0.02em.
- Visual token treatments:
  - **Achieved:** Background `#E8F5E9`, Text `#2E7D32`.
  - **Active:** Background `#EEEDF7`, Text `#1E1B4B`.
  - **Off-Track:** Background `#FEF3C7`, Text `#B45309`.
  - **Overdue:** Background `#FFEBEE`, Text `#D32F2F`.
  - **Cancelled:** Background `#F5F5F5`, Text `#757575`.

### Input Fields
- Background `#FFFFFF`, border `1px solid #EADDCF`, corner radius `12px`, padding `14px 16px`.
- Text size `16px` to prevent iOS zoom triggers.
- Active focus state: border shifts to `#C8702A` with an ambient copper halo (`0 0 0 3px rgba(200, 112, 42, 0.15)`).
- Dedicated currency inputs feature a permanent `₹` prefix anchored in `#1E1B4B` weight 600.

### Checkboxes & Radios
- Size `20px × 20px`. Border `1.5px solid #EADDCF`.
- Selected state fills with `#C8702A` displaying a crisp `#FFFFFF` micro-check. Checkbox corner radius `6px`; radio radius circular.

### Pot Fill Indicator (Custom Gauge)
- Proprietary visual indicator depicting the liquid accumulation state.
- Employs a stylized fluid wave shape inside an organic vessel silhouette or layered horizontal band using `#C8702A` with an overlay reflection of `rgba(255, 255, 255, 0.2)`.