# Paster App Icon Exploration

## Goal

Create six independent square character-image candidates for Paster, a local-first, keyboard-first macOS clipboard manager. The exploration should add memorability without losing the product ideas of collecting, retrieving, and quickly delivering clipboard content.

The six images are concept candidates only. They do not replace the existing app icon or update the Xcode asset catalog until the user selects a winner.

## Directions

### A — Card Sprite

Directly represents clipboard cards and pasted snippets. The character is a single rounded card-like creature with one broad layered tab as its defining feature. It should feel alert, capable, and friendly rather than childish.

- `A1`: lower-left emergence; warm ivory and deep navy character; muted coral background.
- `A2`: lower-right emergence; soft cyan and dark teal character; muted apricot background.

### B — Hamster

Represents collecting and remembering clipboard history. Use a compact round head and one broad cheek region as the species-defining feature.

- `B1`: lower-left emergence; caramel and deep cocoa character; muted teal background.
- `B2`: lower-right emergence; warm cream and berry character; muted blue background.

### C — Pigeon

Represents fast delivery and automatic paste. Use a plump bird silhouette and one broad rounded wing as the species-defining feature; the beak must be short and blunt.

- `C1`: lower-left emergence; powder blue and deep navy character; muted mustard background.
- `C2`: lower-right emergence; warm white and plum character; muted sage background.

## Shared Visual Rules

- Generate each candidate as a separate full-bleed 1:1 square image, approximately 1536 × 1536.
- Use exactly three semantic colors: two character colors and one solid background color.
- Build the character from roughly 4–7 large shapes with one dominant continuous silhouette.
- Fill about 85–95% of the square and emerge from the assigned lower corner; never center the character.
- Use thick, rounded, weighty forms with a readable 32 × 32 silhouette.
- Use two simple eyes and only add a tiny mouth when it improves the expression.
- Apply only an almost imperceptible neo-skeuomorphic sense of depth.
- Include no text, watermark, frame, border, scenery, extra subject, thin line, sharp tip, decorative detail, photorealistic material, strong 3D rendering, or external cast shadow.
- The generation prompt describes only a square character image and does not mention logos, branding, app icons, or icon assets.
- Generate all candidates once, preserve every result as returned, and do not silently retry or post-process them.

## Delivery

Save the six original candidates in a new project-local exploration directory and present all six together in the visual companion, labeled `A1`, `A2`, `B1`, `B2`, `C1`, and `C2`. Report each candidate's direction, corner, dimensions, saved path, prompt, color mapping, generation provider, and constraint-delivery mode.

No selected candidate is installed into `art/icon-master.png` or `Paster/Assets.xcassets/AppIcon.appiconset` during this exploration.

## Additional Comparison Rounds

Following the first-round review, generate two more independent six-image rounds without using earlier results as image references. Preserve the same three subjects and corner split so the comparison isolates new color and personality treatments:

- Round 2: calmer, more restrained treatments suitable for a professional desktop utility.
- Round 3: bolder, higher-contrast treatments optimized for memorability at small Dock sizes.

Each round contains `A1`/`A2` Card Sprite, `B1`/`B2` Hamster, and `C1`/`C2` Pigeon variants. Odd variants emerge from the lower-left and even variants emerge from the lower-right. Prefix saved files and report labels with `R2-` or `R3-` to keep all 18 candidates unambiguous.

## Round 4 — Non-Mascot macOS Icons

Generate one six-image round without using the `ip-as-logo` skill or its mascot, corner-emergence, and three-semantic-color rules. Use the built-in general image-generation workflow to explore professional, centered macOS utility icons:

- `R4-D1` and `R4-D2` — Card Stack: centered layered clipboard cards, respectively using a direct frontal stack and a slightly fanned stack. This is the recommended direction because it communicates clipboard history immediately and preserves continuity with the existing icon.
- `R4-E1` and `R4-E2` — Fast Paste: a card moving through a short rounded flow path or slot. Keep the motion symbol compact so it does not resemble a generic file-transfer app.
- `R4-F1` and `R4-F2` — Local Vault: clipboard cards combined with a broad shield or vault silhouette. Keep the protection cue secondary so the icon does not read primarily as a password manager.

All six candidates use a centered subject on a polished macOS rounded-square base, restrained dimensional lighting, broad geometry, and strong small-size contrast. Use no mascot, face, eyes, text, letters, keyboard glyphs, watermark, thin detail, photorealism, or presentation frame. Generate each candidate independently as a full-resolution square image, save every returned result without automatic retries, and do not replace the current app icon during exploration.

## Round 5 — D1/D2 Refinement

Refine the two Card Stack candidates from Round 4 as image-based edits, preserving their established compositions while aligning them to one calmer professional palette. Produce exactly one refinement for each source image and label the results `R5-D1` and `R5-D2`.

### R5-D1 — Frontal Stack

- Preserve the direct frontal stack and the clear three-record history metaphor from `R4-D1`.
- Replace the electric blue base with a deep graphite-indigo rounded-square background close in character to the calmer `R4-D2` base.
- Use warm ivory for the front card, cobalt blue and teal for the rear cards, and reserve amber for the front clip only.
- Reduce the front card to two broad content bars and remove nonessential surface detail.
- Lower the plastic gloss and soften highlights while retaining enough shallow depth for a native macOS icon.

### R5-D2 — Fanned Stack

- Preserve the compact fanned three-card arrangement and slight perspective from `R4-D2`.
- Keep a deep graphite-indigo base, slightly richer and cleaner than the existing gray-blue background.
- Use the same warm ivory, cobalt blue, teal, and restrained amber palette as `R5-D1`.
- Replace the photo panel, dots, and form-like micro-content with two or three broad clipboard-history bars.
- Enlarge the central silhouette slightly, simplify overlaps, and reduce photorealistic texture and highlight intensity.

### Shared Acceptance Criteria

- Both refinements must look like members of the same icon family, differing primarily by frontal versus fanned composition.
- The clipboard-history meaning must remain readable at 32 × 32 without relying on small content details.
- Retain the macOS rounded-square base with genuinely transparent outer corners.
- Use no text, letters, numbers, keyboard glyphs, mascot features, arrows, cloud or sync badges, watermark, presentation frame, external scene, thin detail, or harsh reflections.
- Save the full-resolution outputs beside the Round 4 assets, preserve the original Round 4 files, and update the visual comparison page without replacing `art/icon-master.png` or the Xcode AppIcon asset catalog.

## Round 6 — D2 Multi-Content Refinement

Round 6 supersedes only the content-simplification decision for the D2 direction. The important product signal in `R4-D2` is that Paster retains more than plain text: the front clipboard visibly contains different kinds of cached content, including a recognizable image preview. Generate one candidate labeled `R6-D2`, using `R4-D2` directly as the image-edit target rather than deriving it from `R5-D2`.

### Content Hierarchy

- Preserve the compact three-card fan, slight perspective, and large warm-ivory front clipboard from `R4-D2`.
- Preserve three visibly different content regions on the front card: one broad teal preview band, one amber text-summary panel containing exactly two broad cream lines, and one large cobalt-blue image thumbnail.
- Keep the image thumbnail recognizable at small sizes with exactly two simplified mountain shapes and one circular sun. Do not replace it with generic lines or a photo glyph.
- Simplify the rear cards by removing tiny circular bullets and thin form details; use only one or two broad content bars so they support rather than compete with the front card.

### Palette and Finish

- Change the base to the calm deep graphite-indigo used by the Round 5 direction, avoiding both the electric blue of `R4-D1` and a dull gray cast.
- Retain the teal, amber, cobalt blue, and warm ivory content palette because the color separation helps communicate multiple cached content types.
- Reduce harsh plastic highlights and photorealistic micro-texture without flattening the softly dimensional native macOS character of `R4-D2`.
- Preserve the large centered silhouette, safe margins, rounded geometry, and 32 × 32 readability.

### Generation and Delivery

- Produce exactly one `R6-D2` visual-comparison candidate and preserve the returned result without a concept retry.
- Do not ask the image generator to draw, display, or simulate a transparency checkerboard. For this comparison draft, prefer a clean full-square dark backdrop if real alpha transparency is not returned naturally; production alpha cleanup is deferred until a final direction is selected.
- Use no text, letters, numbers, keyboard glyphs, mascot features, arrows, cloud or sync badges, watermark, presentation frame, external scene, thin detail, or additional content panels.
- Save the full-resolution output beside the previous round assets and compare `R4-D2`, `R5-D2`, and `R6-D2` together. Do not replace `art/icon-master.png` or the Xcode AppIcon asset catalog during this round.
