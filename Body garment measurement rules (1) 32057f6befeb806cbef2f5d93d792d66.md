# Body/garment measurement rules (1)

### Body Profiling  - What and how

### TECH is used within the mobile device to scan the user's body and extract precise spatial measurements in three dimensions. These scans form the foundation of body profiling logic:

· The scan captures topography across the body to identify key width and vertical length breakpoints.

· Using depth data, we extract:

- M1 (Shoulder Width): Widest part across shoulders and arms next to the body
- M2 (Hip Width): Widest part across the hips (side view needed)
- M3 (Waist): Midsection
    - V1 (Torso Height): From the top of the head to the widest part of the hip (M2 location)
    - V2 (Leg Length): From the widest part of the hip (M2 location) to the floor

# TECH scanning ensures body data is tailored to the individual, removing guesswork and increasing outfit confidence. It also powers wardrobe measurement enabling garment size validation and better fit recommendations. Golden rules are applied based on the measurements.

These define horizontal and vertical proportions and determine styling guidance.

# **BODY CLASSIFICATION & CALCULATION ENGINE**

## **Horizontal Body Typing Logic (Women) — cm-based (Golden Rule process)**

**Inputs from TECH (cm):** M1, M2, M3)

| **Woman Condition** | **Classification only (NEVER displayed)** | **Supportive Message Displayed to User** |  |  |
| --- | --- | --- | --- | --- |
| (abs(M1 - M2) <= 7.62cm) and (M3 < M1 & M3 < M2) – in essence shoulders and buttocks differ by less than 7.62 cm and there is a defined waist, M3 is smaller than M1 and M2 – the difference of waist to M1 and M2 should be >7.62  - clearly defined waist | Hourglass | 
  “Your beautiful
  proportions mean we can highlight your natural waist and celebrate your
  balanced curves with styles that follow your silhouette.”
   |  |  |
| (abs(M1 - M2) <= 7.62) and (abs(M3 - M1) <= 7.62 and abs(M3 - M2) < 7.62) same as Hourglass but no defined waist | Rectangle | 
  “Your elegant frame
  gives us the opportunity to create soft curves and define a graceful
  waistline with clever styling.”
   |  |  |
| M1 > M2 + 7.62 (broad top, narrow bottom) | Inverted Triangle | 
We’ll focus on balancing your confident shoulders with styles that enhance your lower half and create soft harmony
   |  |  |
| M2 > M1 + 7.62 (narrow top, broad bottom) | Triangle | 
  “Your gorgeous hips
  give us a chance to draw attention upward and create beautiful balance with
  styles that flatter your shape.”
   |  |  |
| M3 > M1 + 7.62 and / or M3 > M2 + 7.62 (waist is broader than shoulders or bottom) | Round | 
  “Now that we know
  your lovely shape, we can choose styles that enhance your best features and
  softly define your waistline.”
   |  |  |

Vertical Proportions (Woman) 

**Update Vertical Logic (in cm)**

- **Balanced**:abs(V1 - V2) <= 6.35
- **Long Torso / Short Legs**:V1 > V2 + 6.35
- **Short Torso / Long Legs**:V2 > V1 + 6.35

**Add** – if person is short, less than **1.65cm** then this should be considered as part of the styling, clothing needs to create length by adding vertical lines. Vertical lines in the middle, slims the person as well as add length. For jackets, keep a single line in front vs open jacket as this will shorten them further and add width.

## **Men - less complicated:**

**Updated Logic for Men: Meaningful Proportion Detection**

**Threshold for Shoulder-Hip Imbalance**

- Shoulders naturally broader than hips? ✔ No action.
- **Difference between M1 and M2, Only flag if:**M1 (shoulders) > M2 (hips) + **15 cm** → triggers balance guidance*This accounts for extreme cases like bodybuilders or dramatic imbalance.*

**Waist Proportion Analysis**

Let’s break this down:

We compare **M3 (waist)** to both **M1 (shoulders)** and **M2 (hips)**:

- **Waist significantly larger than both shoulders + hips** → guides toward cuts that smooth and streamline the midsection.

Update Detect waist shape:

- Tech can map cross-section shape at waist level:
    - **If waist front-to-back diameter > side-to-side diameter by meaningful amount – greater than 15cm** → weight more in front (belly prominence)
    - **If relatively even all around** → tube-like waist distribution

Why this matters:

- **Front-heavy waist** → style guidance focuses on structured upper body, longer lines, minimal volume in front.
- **Tube shape** → guidance emphasizes shaping at shoulder/chest and tapered pants or jackets to create dimension.

**Updated Positive Messaging for Men**

| **Detected Proportion** | **Supportive Message** |
| --- | --- |
| Shoulders 15 cm+ wider than hips | “Let’s balance your strong upper body with styles that add subtle structure below — for a confident, polished silhouette.” |
| Hips 15 cm+ wider than shoulders | “We’ll choose cuts that strengthen your upper profile and bring everything into sleek proportion.” |
| Waist larger with front prominence | “We’ll focus on clean lines and cuts that smooth and flatter your midsection — helping you look sharp and feel great.” |
| Waist larger with tube shape | “We’ll add shape where it counts, using smart tailoring for a crisp, confident look.” |
| Balanced proportions | “Great proportions — let’s tailor the fit and style to suit your life and personality.” |

# For outfit generation and garment analysis, it need to support the Golden Rules:

This uses the combination of the Body features the person want to emphasize, their scan, and tone.

**Larger Breasts**- Open chest area- Avoid large pockets on breasts- Avoid button shirts if the chest is quite large- V necks- Low scoop necks- Empire line- Sweetheart necks- Soft cowl necks- Square necks- Single-breasted styles- Avoid bulk in fabrics- Avoid large ruffles

**Smaller Breasts**- Can afford volume- Pockets on breasts- Ruffles- Higher necklines (if applicable - low, deep plunging necklines)- V necks- Scoop necks- Square necks- Sweetheart necks- Cowl necks- Roll necks

**Heavy Arms**- Avoid clinging sleeves, avoid heavy, thick fabrics- Avoid heavy, bulky accessories on the arm. Use light materials for coverage when needed

**Thin Arms**- You can use thicker fabrics and more volume in fabric- If very thin, medium to thicker accessories on the arm, depending on her personality

**Thick Neck**- Medium collars- Open the neck area with a lower neckline- Avoid a thick roll neck- This is a case-by-case analysis

**Thin Neck**- She can afford higher necklines and thicker collars- This is a case-by-case analysis

**Larger Bottom**- Bring jacket and top lengths below the widest part of the bottom or into the waist where applicable- High yoke on denim jeans- High back pockets- Keep pockets and details plain; avoid embellishment on the bottom- No thick waist or drawstring to thicken the waist- A dark pant or denim is flattering

**Flat Bottom**- She can afford embellishment and details on the back pocketsAvoid for Wide Shoulders- Avoid horizontal stripes- Avoid bold patterns + prints- Avoid shoestring straps- Avoid double-breasted- Avoid thick, bulky fabrics- Avoid razorback tops- Avoid halter necks- Avoid high necks- Avoid a high roll neck- Avoid large epaulettes on shoulders- Avoid puffed sleeves- Avoid wide necks- Avoid wide square necks- Strapless will depend on the client’s features- Avoid boatnecks- Avoid batwing sleeve

**To Do for Wide Shoulders**- Small patterns + prints- Wide shoulder straps- Single-breasted- Thinner fabrics- Lower necklines, open chest area- V necks, scoop necks- Cowl (soft)- Sweetheart necks- Cold shoulders- A one shoulder top can work (depends on the client’s features)- Cap sleeve on an angle- Keep shape under the arm to the waist where possible

**Hourglass Tips**- Keep shape (keep her waist)- Can wear most cuts and styles of dresses and skirts (depends on her size and features)- All jeans – (depends on size and features)- An hourglass with no lumps and bumps can enjoy fitted, clingy dresses, tops, and skirts to show off her body shape (this once again depends on the client)- Fitted jackets to enhance the waist- Keep their balance from top half to bottom – they can be easily overbalanced

**Inverted Triangle Tips**- Refer to tips on wide shoulders- Keep shape on the top half- Avoid boat necks- Avoid batwing tops- Avoid thick jackets- Avoid shoestring shoulder straps- Think plain colours on top- Fit and flare dresses- Shirt dresses- Straight skirts- Full skirts- Pattern and print on the lower half or running right through the body- Pockets on hips- All jeans! (Avoid skinny if possible)- Avoid any horizontal stripes or lines on the top half, these can be useful from the waist down, depending on tummy area- A peplum top can be a clever way to create balance

**Rectangle Tips**- She is similar to the hourglass, like an hourglass, if we overbalance her, she turns into another shape, Eg: A triangle or Inverted Triangle

**Triangle Tips**- The plan is to visually widen the shoulders- Details, patterns, and prints for the upper half of the body- Boat necks – All other necklines depend on body features- Horizontal stripes (top half only)- Shoestring straps on shoulders- Racerback tops- Halter necks- Wrap tops, swing coats- Double-breasted jackets- Wide lapels- Fitted tops and jackets- Cinched in waist where possible- Epaulettes on shoulders- The lower half needs to be kept simple; plain colours are preferred- Use pattern/print if running through from top to bottom, e.g. a dress- Straight-cut trousers and jeans – wider leg where applicable, e.g. if on an hourglass – slightly wider on the lower half of the body, outer thigh issues- Avoid whiskers through the thigh area, we don’t want to draw attention here- Avoid cargo pants and large pockets through the front and side of the upper thigh area- Avoid pockets on hips- Avoid pleats- Avoid skinny jeans and pencil skirts- Some straight skirts may work (depends on the individual)- Think yoga pants as a soft, casual alternative to leggings or tapered ankle-length trousers- Think plain colours on the bottom or tonal colours running right through from top to bottom

**Oval Tips**- Think a heavier body all over when you think of an oval with emphasis on the tummy spilling out through the waist and front- We do not call someone an oval – we have to fudge it by saying “Hourglass with…”- Necklines can be very individual; depends on their features, e.g. bust- Avoid bulk in all fabrics- Create vertical lines running through the body- Pattern and print – small and muted in colour running right through the body- Tonal colours right through the body- Empire lines- Where possible, use the bust for blouses to sit off- Avoid clingy, clingy fabrics!- Avoid belts across the tummy- Draw eyes to décolletage area- Flat waist pants and skirts- High waist pants and skirts to tuck in tummy- Wear tops longer to the widest part of the bottom or longer if needed to hide a low hanging tummy- Side zips where possible- Avoid pockets on hips and stiff cargo pants- Avoid leggings and skinny jeans- Avoid pencil skirts- Think of fabrics that simply flow over the body without adding any volume or weight- Always keep an oval simple – use colour cleverly, draw the eye away from the middle section- Avoid pleats on the tummy- Avoid a large print on the tummy, e.g. a big set of lips

**Vertical proportions:**

**Short Waist and Longer Legs**- Longer line tops and jackets- Long vests, longer cardigans- Avoid a wide waist belt- Can wear a dropped waistline in a dress- Can wear a lower rise pant and jeans and skirt- Colours running right through can lengthen- Avoid crop tops and jackets- Cuff on bottom of trousers (depends on height)- Flat shoe – depends on height

**Long Waist and Shorter Legs**- Note: The person’s height plays a huge factor in vertical proportions, and then the shoe they are prepared to wear!- They have room to wear higher-waisted pants and skirts and wide waist belts (depending on the tummy area)- Avoid drop-waist dresses- They can wear a different colour on the top tucked into a high-waist pant or skirt, as they have room!- Short leg depends obviously on height and how short the legs actually are, and will they wear heels to elongate. This is where logic should kick in!- Generally, if short legs and won’t wear a heel, no wide leg, no cuff on the bottom, don’t roll a cuff, hem of skirt or dress close to the knee area

**Also have neckline etc details** 

**I also have guidance info on shoes, accesories and fabric** 

Here is the details for 

# Garment Tagging and measurements

Capture **structural garment measurements** that affect **visual balance on the body**. These measurements allow the styling engine to align garments with the user’s **body proportions (M1, M2, M3, V1, V2)** and styling goals (highlight / soften features).

Below is the **republished tagging system including the critical garment measurements** that influence styling outcomes.

---

# Garment Tagging System for My Studio (with Measurements)

## 1. Category (AI detected)

Primary garment group.

Examples:

- Top
- Bottom
- Dress
- Outerwear
- Shoes
- Accessory

---

# 2. Subcategory (AI detected)

Examples:

- T-shirt
- Button shirt
- Blazer
- Jeans
- Midi dress
- Sneakers

---

# 3. Colour Intelligence

### Primary Colour

Example: Navy, Black, White

### Colour Harmony

Mapped to the user’s tone profile.

Examples:

- Warm compatible
- Cool compatible
- Neutral

---

# 4. Pattern

Examples:

- Solid
- Striped
- Floral
- Checked
- Geometric
- Animal print

---

# 5. Fabric

Examples:

- Cotton
- Linen
- Denim
- Wool
- Silk
- Knit
- Leather

Fabric influences:

- weather suitability
- structure
- drape

---

# 6. Silhouette / Fit

Examples:

- Tailored
- Relaxed
- Oversized
- Structured
- Flowing
- Body-skimming

This affects how garments balance the user’s **body proportions**.

---

# 7. Seasonality

Examples:

- Warm weather
- All season
- Cold weather

Used with weather integration.

---

# 8. Occasion Suitability

Examples:

- Casual
- Work
- Smart casual
- Evening
- Formal
- Active

Used by:

- Travel planner
- Event styling
- Daily outfit suggestions

---

# 9. Layer Role

Examples:

- Base layer
- Mid layer
- Outer layer

Outfit logic example:

Base: T-shirt

Mid: Sweater

Outer: Jacket

---

# 10. Visual Weight (Important)

Examples:

- Light
- Medium
- Heavy

Professional stylists use visual weight to balance outfits.

Example:

Light blouse + heavy boots + structured jacket.

---

# 11. Critical Garment Measurements (NEW)

These measurements allow the styling system to adjust for **body proportions and styling preferences**.

---

## Sleeve Length (tops / dresses)

Examples:

- Sleeveless
- Thin strap
- Cap sleeve
- Short sleeve
- Elbow sleeve
- Three-quarter sleeve
- Long sleeve

Styling impact examples:

Thin straps → emphasise shoulders

Cap sleeves → broaden shoulder appearance

Long sleeves → streamline arms

---

## Shoulder Width / Structure

Examples:

- Narrow shoulder cut
- Standard shoulder
- Structured shoulder
- Padded shoulder

Impact:

Structured shoulders → balance wider hips (triangle shape).

---

## Neckline

Examples:

- Crew neck
- V-neck
- Scoop neck
- Boat neck
- Square neck
- Halter
- High neck
- Collared

Styling impact examples:

V-neck → elongates torso

Boat neck → broadens shoulders

---

## Garment Length (tops / jackets)

Examples:

- Cropped
- Waist length
- Hip length
- Mid-thigh
- Longline

Impact:

Cropped → emphasises waist

Longline → elongates torso

---

## Waist Placement (dresses / bottoms)

Examples:

- High-waisted
- Natural waist
- Drop waist

Impact:

High waist → lengthens legs.

---

## Bottom Fit

Examples:

- Skinny
- Straight
- Wide leg
- Bootcut
- Tapered
- Flared

Impact:

Wide leg → balances broad shoulders

Skinny → emphasises hips and legs.

---

## Skirt / Dress Length

Examples:

- Mini
- Above knee
- Knee length
- Midi
- Maxi

Impact:

Midi → elongates silhouette

Mini → emphasises legs.

---

## Strap Width (important for body balance)

Examples:

- Thin strap
- Medium strap
- Wide strap

Impact:

Thin straps → emphasise shoulders

Wide straps → soften shoulder width.

---

# 12. Behaviour Tags (generated over time)

### Wear Frequency

Often worn

Occasionally worn

Rarely worn

---

### Confidence Rating

Based on daily outfit feedback.

Examples:

High confidence

Neutral

Not preferred

---

### Signature Piece

Items strongly associated with the user’s style.

---

# Example Garment Record (Full)

White Linen Shirt

Category: Top

Subcategory: Button shirt

Colour: White

Pattern: Solid

Fabric: Linen

Silhouette: Relaxed

Neckline: Collared

Sleeve length: Long sleeve

Garment length: Hip length

Visual weight: Light

Occasion: Casual / Smart casual

Season: Warm / All season

---

# Why this measurement layer is important

These attributes allow the AI to perform **true styling logic**, such as:

Triangle body → recommend structured shoulders, wear thin straps, wear t-Shirt with sleeves that ends in line with bust.

Broad shoulders → avoid cap sleeves, avoid thin strpas

Short torso → prioritise longer tops

Petite → avoid overly long garments

This makes StylistA function more like a **professional stylist**, not just a wardrobe catalogue.

# StylistA Outfit Balancing Algorithm

## Core principle

The algorithm should aim to create outfits that:

- feel visually balanced
- align with the user’s style preferences
- support the user’s colour profile
- respond to weather / occasion
- respect the user’s “highlight” and “soften” selections

---

# 1. Start with the user profile inputs

## Body proportion data

From your existing logic:

- **M1** = widest part across shoulders / arms
- **M2** = widest part of hips
- **M3** = waist
- **V1** = top of head to widest part of hip
- **V2** = widest part of hip to floor

These determine the proportion profile.

---

## User preference layer

From **Celebrate Your Body**:

- features to **highlight**
- features to **soften**
- no-preference zones

This should override “default” styling logic where needed.

Example:

If the body logic says “balance hips,” but the user wants to **highlight hips**, the engine should respect the user preference.

---

## Style identity layer

From Personal Style:

- Classic
- Minimal
- Sporty
- Romantic
- Edgy
- etc.

This changes the garment selection style, not just the balancing rule.

---

## Colour profile layer

Used to prioritise:

- flattering colours near the face
- outfit harmony
- contrast balance

---

# 2. Define the balancing objective

### The system should determine the main styling goal for that user and outfit. **Refer above for all the Prioritise  / Avoid Golden Rules already provided, below a few included as reference.**

Examples:

- broaden upper body visually
- soften shoulder width
- define waist
- elongate legs
- lengthen torso
- reduce visual bulk at hips
- create vertical line
- increase structure
- soften structure

This becomes the **primary outfit objective**.

---

# 3. Garment rules by body balance goal

## A. If hips are wider than shoulders

Example: triangle / pear proportion logic

### Primary goal

Create more visual presence on the upper body and define balance.

### Prioritise

- boat necks
- square necks
- structured shoulders
- shoulder detail
- wider straps
- lighter / brighter tops
- cropped jackets
- upper-body layering

### Avoid deprioritise

- very thin straps
- narrow shoulder cuts
- very dark / minimal tops if bottom is visually dominant
- clingy hip emphasis if user selected “soften hips”

### Bottom logic

- darker bottoms
- clean lines
- A-line or soft drape where appropriate
- avoid excessive hip-pocket volume if softening hips

---

## B. If shoulders are wider than hips

Example: inverted triangle logic

### Primary goal

Soften the upper body and create more presence below the waist.

### Prioritise

- V-necks
- scoop necks
- raglan or softer shoulder lines
- darker or simpler tops
- wide-leg bottoms
- pleated / textured skirts
- lighter or brighter lower half
- flared or bootcut shapes

### Avoid deprioritise

- cap sleeves
- padded shoulders
- boat necks
- halter cuts
- shoulder embellishment

---

## C. If waist is significantly narrower than shoulders and hips

Example: hourglass logic

### Primary goal

Maintain natural balance and define the waist.

### Prioritise

- wrap styles
- belting
- tailored fits
- waist shaping
- fitted jackets
- high-waisted bottoms
- dresses with waist definition

### Avoid deprioritise

- boxy oversized shapes that erase the waist, unless selected by style preference
- dropped waist silhouettes

---

## D. If shoulders, waist and hips are more aligned

Example: rectangle logic

### Primary goal

Create shape, movement and waist definition if desired.

### Prioritise

- peplum
- belting
- cropped layers
- texture contrast
- curved silhouettes
- strategic drape
- wide-leg or tapered combinations depending on height balance

### Avoid deprioritise

- shapeless straight cuts head-to-toe
- overly boxy matching separates unless style preference is Minimal / Relaxed

---

# 4. Vertical balance rules

Use **V1 and V2**.

## If torso appears longer than legs

### Goal

Lengthen the leg line.

### Prioritise

- high-waisted bottoms
- cropped jackets
- shorter tops or tucked styling
- shoes close to skin tone or lower garment tone
- uninterrupted vertical lower half

### Avoid

- long untucked tops
- drop-waist silhouettes
- strong horizontal breaks at hip

---

## If legs appear longer than torso

### Goal

Create more visual length in the torso.

### Prioritise

- longer tops
- hip-length jackets
- mid-rise bottoms
- layered upper body
- horizontal detail on top

### Avoid

- very cropped tops
- extreme high-waisted bottoms

---

## If user is petite

### Goal

Maintain proportion and avoid visual overwhelm.

### Prioritise

- shorter hemlines relative to frame
- cleaner silhouettes
- moderate scale prints
- cropped or waist-length outerwear
- not too many heavy layers

### Avoid

- overly longline jackets
- very oversized garments
- excessive visual breaks

---

## If user has a longer frame / tall line

### Goal

Use scale and structure confidently.

### Prioritise

- longer lengths
- bolder proportions
- layering
- larger accessories / prints if aligned with style

---

# 5. Garment attribute logic

These are the tags that affect balancing.

## Neckline

- **Boat / square** = broadens upper body
- **V-neck** = elongates and softens upper body
- **Crew neck** = shortens / closes neckline visually
- **Scoop** = softens and opens chest area

## Sleeve

- **Cap sleeve** = visually broadens shoulder line
- **Thin strap** = can make shoulders appear sharper or broader
- **Long sleeve** = streamlines arm line
- **Elbow / 3/4** = draws attention to waist / mid body depending on fit

## Shoulder structure

- **Padded / structured** = strengthens upper body
- **Soft shoulder** = reduces upper body dominance

## Garment length

- **Cropped** = highlights waist, shortens torso, lengthens legs
- **Hip length** = neutral
- **Longline** = elongates torso and overall frame

## Bottom shape

- **Wide leg** = adds lower-body visual weight
- **Skinny / slim** = emphasises leg line and hip area
- **Bootcut / flare** = balances upper body
- **Straight leg** = balanced, versatile neutral option

## Strap width

- **Thin strap** = more exposed shoulder line
- **Wide strap** = more grounded, often more balancing

---

# 6. Colour placement logic

This is very important.

## To highlight upper body

- lighter / brighter / more detailed tops
- stronger contrast near the face

## To soften upper body

- darker / lower contrast / simpler tops

## To highlight lower body

- colour, print, texture or lighter shades below the waist

## To create vertical line

- column dressing
- low-contrast transitions
- longline outerwear

## To define waist

- contrast at waist
- belts
- waist seam placement

---

# 7. Visual weight balancing

Every item should carry a **visual weight** tag:

- light
- medium
- heavy

The outfit engine should avoid all visual weight accumulating in one area unless intentional.

Example:

- heavy boot + heavy oversized coat + dark fitted legging may overweight the lower silhouette for some users
- light blouse + heavy structured trouser may create good balance for broader shoulders

Rule:

The system should aim for **distribution of visual weight** across the body according to the balancing objective.

---

# 8. Outfit generation sequence

A good outfit engine should build in this order:

## Option A: separates

1. Select the **anchor piece**
    - usually top or bottom based on objective, weather, occasion
2. Select balancing counterpart
3. Select shoes based on occasion + visual weight
4. Add outer layer if required
5. Add accessories only if consistent with style profile
6. Validate against colour harmony and highlight / soften rules

## Option B: dress-based outfit

1. Select dress with suitable silhouette
2. Select shoes
3. Add outerwear if needed
4. Add accessories
5. Validate against body balance and occasion

---

# 9. Scoring logic

Each potential outfit should be scored.

## Suggested score dimensions

- **Body balance score**
- **Colour harmony score**
- **Style identity score**
- **Weather suitability score**
- **Occasion suitability score**
- **User preference score**
- **Wearability score** based on past feedback

Then rank outfit options.

Example:

Final Score =

30% body balance

20% style identity

15% colour harmony

15% user preference

10% weather

10% occasion

You can adjust weighting over time.

---

# 10. Feedback loop

The algorithm should improve based on user feedback.

If the user consistently says:

- “felt confident” in structured waist-defined looks
- “not for me” on boxy layered outfits

then the system should reweight future outfit scoring.

This is where StylistA becomes smarter than a static styling app.

---

# Example logic in practice

## User profile

- hips wider than shoulders
- narrow waist
- cool colouring
- prefers highlighting waist
- prefers softer styling on hips
- style: Classic + Refined

## Strong outfit recommendation

- light cool-toned structured top
- square or softly open neckline
- cropped tailored blazer
- dark straight or softly wide-leg trousers
- pointed flat or sleek boot
- minimal jewellery

Why it works:

- adds presence up top
- defines waist
- softens hips
- aligns with colour tone
- matches style identity

---

# Critical rule for StylistA

The algorithm should **never show the user their body category label**.

Instead, it should only express the result as positive style guidance.

Example:

> This look creates beautiful balance and softly defines your waist.
> 

Not:

> This works because you are a triangle.
> 

---

# Best-practice hierarchy

When rules conflict, use this priority:

1. User comfort / highlight-soften preferences
2. Occasion appropriateness
3. Weather practicality
4. Body balance optimisation
5. Style identity
6. Trend or inspiration logic

This ensures the user always feels respected and in control.

---

# My recommendation for implementation

Build the engine in **three layers**:

### Layer 1: Structural styling engine

Body profile, vertical proportions, feature overlays, garment architecture, colour placement

### Layer 2: Preference and comfort engine

Highlight / soften choices, personal style, modesty, lifestyle

### Layer 3: Learning engine

Outfit ratings, mood/confidence feedback, most-worn pieces, ignored recommendations

That structure keeps **body profiling and colour as the lead drivers**, while preferences remain influential but not dominant.

Uses feedback from daily check-ins, mood tracking, most-worn items

That structure will make StylistA much more robust and explainable.

If you want, I can turn this next into a **developer-ready decision table** showing:

**body objective → garment rules → avoid rules → example outputs**.

| Body Profile / Feature | Detection Logic | Primary Styling Objective | Prioritise (Use) | Avoid / Deprioritise | Colour Placement Guidance | Critical Garment Measurements / Tags | Example Outfit Logic | User-Facing Positive Messaging | Priority Weight (Engine) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Triangle (hips wider than shoulders) | M2 > M1 | Add visual presence to upper body and simplify lower body | Boat necks, square necks, structured shoulders, lighter/brighter tops, cropped jackets, upper body detail | Hip pockets, cargo pants, whiskering at thighs, pleats at hips, skinny jeans | Brighter or lighter colours near face; darker bottoms | Shoulder structure, neckline width, sleeve type, bottom fit (straight/wide), pocket placement | Light structured top + cropped blazer + dark straight trousers + sleek shoe | This look draws the eye upward and creates beautiful balance. | High |
| Inverted Triangle (shoulders wider than hips) | M1 > M2 | Soften upper body and add visual weight to lower half | V-neck, scoop neck, softer shoulders, wider-leg trousers, patterned skirts, hip pockets | Boat neck, halter neck, shoulder padding, puff sleeves, heavy shoulder details | Darker or simpler tops; colour or pattern below waist | Neckline depth, shoulder structure, bottom width, fabric drape | Soft V-neck top + wide-leg trousers + textured shoe | This look softens the upper body and creates balance through the lower half. | High |
| Hourglass | M1 ≈ M2 and M3 narrower | Maintain natural balance and define waist | Wrap styles, fitted jackets, belted waists, tailored silhouettes | Boxy oversized shapes that remove waist definition | Balanced colour distribution across body | Waist placement, jacket shaping, garment fit | Wrap dress + structured waist belt + streamlined shoe | This look keeps your natural balance and beautifully defines your waist. | High |
| Rectangle | M1 ≈ M2 ≈ M3 | Create shape while maintaining balance | Peplum shapes, cropped layers, texture contrast, waist definition | Straight boxy silhouettes head-to-toe | Use contrast or shape to introduce curves | Waist shaping, layered lengths, garment structure | Textured top + shaped jacket + straight trousers | This look adds shape while keeping everything beautifully balanced. | Medium |
| Oval (midsection emphasis) | Fullness around mid torso | Create vertical line and reduce mid-body bulk | Empire lines, vertical lines, flowing fabrics, tonal colour stories | Belts at tummy, bulky fabrics, pleats on stomach, large prints | Low contrast colour through body for vertical flow | Fabric drape, waist placement, garment length | Longline blouse + straight trousers + open jacket | This look creates a beautiful long line and draws attention upward. | High |
| Short Waist / Long Legs | V1 shorter relative to V2 | Lengthen torso visually | Longer tops, longer jackets, lower rise bottoms | Cropped jackets, wide belts at waist | Continuous colour through torso | Garment length, waist placement | Hip-length top + straight trousers | This look creates lovely balance through your proportions. | Medium |
| Long Waist / Short Legs | V1 longer relative to V2 | Lengthen leg line | High-waisted bottoms, tucked tops, cropped jackets | Drop-waist silhouettes, low-rise bottoms | Contrast between top and high-waisted bottom | Waist placement, bottom rise | Tucked blouse + high-waist trousers + sleek heel | This look beautifully elongates the leg line. | Medium |
| Large Bust | Bust prominence detected | Create open neckline and avoid bulk | V-neck, scoop neck, soft cowl, lightweight fabrics | Large chest pockets, bulky ruffles | Keep colour simple around bust if minimising prominence | Neckline depth, fabric weight | V-neck blouse + tailored trousers | This neckline creates a beautiful open frame for your features. | Medium |
| Small Bust | Bust smaller relative to shoulders/waist | Add dimension to upper body | Ruffles, pockets, texture, higher necklines | Flat unstructured tops with no detail | Lighter or brighter colour near bust | Neckline height, embellishment | Textured blouse + straight jeans | This look adds lovely dimension to the upper body. | Medium |

### How developers should use it

1. **Detection Logic** connects to your body measurement system.
2. **Use / Avoid rules** translate directly into garment scoring.
3. **Critical garment measurements** link to the garment tagging system.
4. **Colour placement guidance** integrates with your warm/cool tone engine.
5. **User-facing messaging** ensures the app never reveals body shape labels.

### Engine hierarchy (as you requested)

1. **Body proportions (M1, M2, M3, V1, V2)**
2. **Colour harmony**
3. **Garment architecture**
4. **User preferences**
5. **Behavioural learning**

Preferences influence suggestions but **do not override strong styling logic**, allowing the app to **gently guide users toward what works best over time**.

[Body/garment measurement rules (2)](https://www.notion.so/Body-garment-measurement-rules-2-32257f6befeb8075ac67c03ff4954540?pvs=21)