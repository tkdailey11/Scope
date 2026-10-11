# 05 — Visual Design System

## Relationship to Relay

Scope should clearly feel like it comes from the same developer as Relay, using the Relay screenshot in `assets/relay_visual_reference.png` as the family reference.

Shared family traits:

- dark navy surfaces;
- blue/cyan accent language;
- restrained purple accents;
- rounded cards and controls;
- translucent sidebar treatment;
- compact, developer-oriented density;
- monospace where code/data is shown;
- clean macOS window chrome.

Scope should be calmer than Relay. Relay is about active sessions and motion; Scope is about precision and configuration.

## Surface hierarchy

Suggested hierarchy:

- Window background: deep navy/blue.
- Sidebar: translucent darker material.
- Main content: slightly lighter blue/navy field.
- Cards: subtle tonal separation, not heavy borders.
- Selected rows: blue-tinted fill with clear text contrast.
- Warnings/errors: rely on semantic system colors where possible.

Prefer native materials and system vibrancy over hand-built heavy glass effects.

## Typography

- UI: San Francisco/system font.
- Code, paths, variables: system monospaced font.
- Use hierarchy through weight and size rather than excessive color.

## Shape language

- Rounded rectangles throughout.
- Avoid extreme pill shapes for everything.
- Cards should use consistent radii.
- Iconography should use thin-to-medium geometric strokes.

## Motion

- Short, subtle state transitions.
- Drag reorder animations on PATH.
- Gentle insertion/removal animations in lists.
- Avoid ambient glow/pulsing effects.

## Final icon direction

See `assets/scope_final_icon_spec.png`.

The selected icon is the refined **Hybrid 1** reticle direction:

- rounded macOS app-icon tile;
- four outer corner brackets;
- four thin cardinal tick marks;
- partial inner circular arcs;
- centered circular focal point;
- cyan → blue → violet accent progression;
- flat/clean rendering with little or no glow.

### Icon construction guidance

Use these as production targets rather than rigid mathematical requirements:

- Master canvas: 1024 × 1024.
- Main mark should remain within roughly 80% of the canvas.
- Background tile uses a macOS-style rounded-square silhouette.
- Center circle is approximately one fifth of icon width.
- Outer corner brackets should visually balance the inner arcs rather than overpower them.
- Cardinal tick marks should be thinner than corner bracket strokes.
- Inner arcs should remain readable at 32 px and simplify gracefully at 16 px.
- Maintain optical symmetry on both axes.

### Reference palette

Approximate reference colors from the selected concept:

- Cyan: `#00D1FF`
- Blue: `#3B82F6`
- Violet: `#A855F7`
- Navy: `#0B1F36`

Production artwork should tune colors by eye against the Scope UI and Relay icon rather than treating these as immutable brand standards.

### Small-size variant

At very small sizes, consider simplifying the inner arcs or increasing spacing rather than simply scaling the 1024 px artwork down unchanged.

## Accessibility

- Never encode scope/state by color alone.
- Maintain strong contrast for code and table text.
- Support increased contrast and reduce transparency settings.
- Ensure keyboard focus rings remain visible.
- Respect Dynamic Type equivalents appropriate to macOS where possible.
