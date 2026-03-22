# Bento Box Wallpaper Screens — Design Spec

## Concept
Replace the 6 empty landing page bento cells with ScreenStudio-style feature showcases:
- **CSS-recreated Apple wallpaper backgrounds** alternating Big Sur (layered gradient hills) and Sonoma (rolling organic hills) shape languages
- **macOS-style floating window** on each (traffic light dots + title bar)
- **Real app UI inside each window**, populated with realistic draft data
- **No animations** — static compositions, confident and clean
- **Unified palette** with color variation per box

## The 6 Bento Boxes

| # | Feature | Grid Size | Wallpaper | Color Palette |
|---|---------|-----------|-----------|---------------|
| 1 | Low stock alerts | Wide (2col) | Big Sur hills | Deep blue → purple → coral |
| 2 | AI purchase orders | Narrow (1col) | Sonoma hills | Teal → emerald → lime |
| 3 | Supplier hub | Narrow (1col) | Big Sur hills | Indigo → violet → pink |
| 4 | Inventory trends | Wide (2col) | Sonoma hills | Amber → orange → warm gold |
| 5 | Weekly reports | Wide (2col) | Big Sur hills | Slate blue → steel → silver |
| 6 | Smart reorder | Narrow (1col) | Sonoma hills | Rose → magenta → plum |

## Wallpaper CSS Approach

### Big Sur Style (boxes 1, 3, 5)
- Dark-to-colorful vertical gradient base
- 3-4 overlapping SVG `<path>` hill shapes with semi-transparent fills
- Each hill layer slightly different hue for depth

### Sonoma Style (boxes 2, 4, 6)
- Light-to-saturated vertical gradient base
- 2-3 gentle rolling SVG `<path>` hill shapes
- Softer, more organic curves than Big Sur

## Floating Window Treatment
- macOS title bar: 3 traffic light dots (red #EF4444, yellow #F59E0B, green #22C55E)
- Title bar background: #f9fafb with bottom border
- Window title text: feature name in grey
- White content area with real UI mockup
- Border-radius: 12px
- Box-shadow: large diffused shadow for floating effect
- Centered in the bento cell with ~15% padding on each side

## Screenshot Content Per Box

### 1. Low Stock Alerts (Wide)
Recreate the alerts list: "Today" group header, 3 alert rows with colored severity dots (red critical, orange warning), alert messages with realistic product names, time stamps, dismiss buttons.

### 2. AI Purchase Orders (Narrow)
Recreate a PO card: PO number, "Draft" status badge, supplier name, item count, total value, order date. Plus the "Generate Draft PO" button with AI icon at top.

### 3. Supplier Hub (Narrow)
Recreate a supplier card: avatar with initials, supplier name, email, phone, lead time, linked variants count, 5-star rating (3 filled).

### 4. Inventory Trends (Wide)
Recreate the stock history bar chart: 14 bars showing stock levels over time, date labels, a mix of heights to show a realistic trend pattern. Title "Stock History (14 days)".

### 5. Weekly Reports (Wide)
Recreate the email report: "Weekly Inventory Report" header, shop domain, top sellers table (3 rows), stockout count, low stock count, reorder suggestions section.

### 6. Smart Reorder (Narrow)
Recreate the AI agent card: "Inventory Agent" title, 3 checkmark feature items (Low-stock detection, Reorder recommendations, Auto-draft POs), "Run Analysis" button.

## Files Modified
- `app/views/landing/index.html.erb` — replace empty bento cells with wallpaper + window markup
- `app/assets/stylesheets/landing.css` — add wallpaper CSS, window chrome styles, responsive handling

## Responsive
- Desktop: full wallpaper + floating window as described
- Tablet (< 900px): single column, reduced window size, wallpapers still visible
- Mobile (< 480px): smaller windows, simplified content if needed
