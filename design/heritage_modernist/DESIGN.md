---
name: Heritage Modernist
colors:
  surface: '#fcf9f6'
  surface-dim: '#dcd9d7'
  surface-bright: '#fcf9f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f1'
  surface-container: '#f0edeb'
  surface-container-high: '#ebe7e5'
  surface-container-highest: '#e5e2e0'
  on-surface: '#1c1c1a'
  on-surface-variant: '#3e4948'
  inverse-surface: '#31302f'
  inverse-on-surface: '#f3f0ee'
  outline: '#6e7979'
  outline-variant: '#bec9c8'
  surface-tint: '#016a6a'
  primary: '#005454'
  on-primary: '#ffffff'
  primary-container: '#0d6e6e'
  on-primary-container: '#9dedec'
  inverse-primary: '#84d4d3'
  secondary: '#914c00'
  on-secondary: '#ffffff'
  secondary-container: '#fe932d'
  on-secondary-container: '#663400'
  tertiary: '#005454'
  on-tertiary: '#ffffff'
  tertiary-container: '#286c6c'
  on-tertiary-container: '#a9ebea'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#a0f0f0'
  primary-fixed-dim: '#84d4d3'
  on-primary-fixed: '#002020'
  on-primary-fixed-variant: '#004f50'
  secondary-fixed: '#ffdcc3'
  secondary-fixed-dim: '#ffb77e'
  on-secondary-fixed: '#2f1500'
  on-secondary-fixed-variant: '#6e3900'
  tertiary-fixed: '#aceeee'
  tertiary-fixed-dim: '#91d2d1'
  on-tertiary-fixed: '#002020'
  on-tertiary-fixed-variant: '#004f50'
  background: '#fcf9f6'
  on-background: '#1c1c1a'
  surface-variant: '#e5e2e0'
typography:
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '800'
    lineHeight: '1.2'
  display-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: '1.2'
  price-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '800'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Be Vietnam Pro
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Be Vietnam Pro
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-bold:
    fontFamily: Be Vietnam Pro
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.4'
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Be Vietnam Pro
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
  caption:
    fontFamily: Be Vietnam Pro
    fontSize: 11px
    fontWeight: '400'
    lineHeight: '1.3'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  container-padding: 16px
  gutter: 12px
---

## Brand & Style

This design system balances the chaotic energy of a traditional wholesale hub with the refined precision of a modern digital marketplace. The brand personality is **Trustworthy, Industrious, and Warm**, moving away from clinical e-commerce toward a tactile, service-oriented experience.

The design style is **Minimalist with Tactile accents**. It prioritizes high-quality product photography and clear information hierarchy to accommodate bulk purchasing decisions. By utilizing a "Warm Minimalist" approach, the interface feels premium yet accessible to the local Colombo merchant, emphasizing clarity through generous whitespace and a sophisticated, earth-toned palette.

## Colors

The palette is rooted in an organic, parchment-inspired base that avoids the harshness of pure white (#FFFFFF is reserved for floating cards only). The use of **Primary Teal** provides a sense of professional stability, while the **Accent Orange** is used sparingly for high-intent actions like "Add to Quote" or "Sale" badges. 

Color application follows a strict hierarchy:
- **Surface Layering:** Use the scaffold color for the main background and the secondary section color to group related content blocks or footers.
- **Interactions:** Use Dark Teal for pressed states of buttons and Light Teal Tint for subtle hover backgrounds or active navigation tabs.
- **Borders:** Use the defined border color for all structural divisions; do not use black or heavy grays.

## Typography

This design system uses **Plus Jakarta Sans** (serving as the modern proxy for the requested Nunito Heavy) for all brand-critical and numerical data to ensure maximum impact and legibility. **Be Vietnam Pro** (proxy for DM Sans) handles the utilitarian aspects of the UI, offering a contemporary and approachable feel.

- **Prices & Headings:** Always use Plus Jakarta Sans Bold/ExtraBold. Wholesale pricing should be the most prominent element on product cards.
- **UI Elements:** Use Be Vietnam Pro for all form labels, navigation links, and body copy.
- **Hierarchy:** Maintain a clear distinction between "Supporting Text" (for metadata) and "Primary Text" (for titles and names).

## Layout & Spacing

This design system utilizes a **Mobile-First Fluid Grid**. On mobile devices, a 2-column or 1-column layout is preferred for product feeds to prioritize large, clear imagery. 

- **The 8px Rhythm:** All vertical spacing and component heights should be multiples of 4px or 8px.
- **Margins:** Screens must maintain a minimum 16px horizontal "Safe Area" margin.
- **Product Grids:** Use 12px gutters between cards to maximize "image-first" real estate while maintaining enough whitespace to prevent a cluttered wholesale look.
- **Sectioning:** Use the Secondary Section color (#F2F2EF) for full-width horizontal bands to break up long scrolling pages.

## Elevation & Depth

Hierarchy is established through **Tonal Layering** and **Ambient Shadows**. 

- **Base Layer:** The scaffold color (#FAFAF8) acts as the canvas.
- **Interactive Layer:** Cards and primary surfaces use White (#FFFFFF).
- **Shadows:** Use a single, soft shadow style for floating elements. 
    - *Style:* `0px 4px 20px rgba(17, 17, 16, 0.06)`. The shadow should be diffused and barely perceptible, intended only to lift the card off the warm background.
- **Separation:** Avoid shadows for nested elements. Use the Border/Divider color (#E8E8E4) with a 1px stroke for internal sectioning within cards or lists.

## Shapes

The shape language is **Rounded**, conveying friendliness and modern polish. 

- **Standard Elements:** Buttons, input fields, and product cards use a `0.5rem` (8px) corner radius.
- **Large Components:** Promotional banners and main containers use a `rounded-lg` (16px) or `rounded-xl` (24px) radius.
- **Product Images:** Images within cards should have a slightly smaller radius than their parent card (typically 4px-6px) to create a "nested" visual effect.
- **Icons:** Use rounded icon sets (e.g., linear icons with rounded caps) to match the typography and shape language.

## Components

### Buttons
- **Primary:** Solid Primary Teal with white text. High-emphasis, 0.5rem rounding.
- **Secondary:** Light Teal Tint background with Primary Teal text. Used for "View Details" or secondary filters.
- **Accent:** Solid Orange for conversion-critical paths like "Place Order."

### Input Fields
- **Search:** Use the Search/Input color (#FBF8F3) with no border or a very subtle tinted border. Use the Muted Text/Icon color (#AEAEA4) for magnifying glass icons and placeholders.
- **Forms:** White background with an #E8E8E4 border. Focused state uses a 1px Primary Teal stroke.

### Cards
- White background, 8px radius, subtle ambient shadow. 
- **Wholesale Card:** Image-first (top 60% of card), followed by a bold price in Plus Jakarta Sans, then the product title in Primary Text.

### Chips & Tags
- Used for categories (e.g., "Textiles," "Electronics").
- Style: Secondary Section background (#F2F2EF) with Secondary Text (#3D3D3A). Pill-shaped (32px height).

### Lists
- Use for bulk inventory lines. Items separated by 1px #E8E8E4 divider. Use "Supporting Text" for SKU numbers and "Primary Text" for stock availability.

### Navigation
- **Mobile Bottom Bar:** White surface, subtle top border. Active icons in Primary Teal; inactive in Muted Icon color.