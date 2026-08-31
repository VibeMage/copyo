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
