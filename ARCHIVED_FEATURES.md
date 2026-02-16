# Archived Features

## Overview

To focus development efforts on perfecting water quality data collection and CODAP integration, Air Quality and Weather & Climate features have been temporarily archived. These features remain fully intact in the codebase and can be easily restored.

## What Was Archived

### 1. User Interface Components
- **Air Quality menu item** (line ~180) - Commented out
- **Weather & Climate menu item** (line ~181) - Commented out
- **Air Quality tab content** (~154 lines) - REMOVED from app.R
- **Weather & Climate tab content** (~216 lines) - REMOVED from app.R

**Note:** The tab content was completely removed (not just wrapped in `if(FALSE)`) because `if(FALSE) { tabItem(...) }` evaluates to NULL, which causes a shiny.tag error in `tabItems()`. The code is preserved in git history.

### 2. Reactive Values
- Air quality reactive values (lines ~891-899)
- Weather reactive values (lines ~901-909)

### 3. Server Logic
- **Air Quality server logic** (lines ~1383-1723)
  - County selection observer
  - Data fetching function
  - Data preview and filtering
  - CSV download handler
  - CODAP export handler
- **Weather & Climate server logic** (lines ~1725-2135)
  - State/county selection observers
  - Data fetching function
  - Data preview and filtering
  - CSV download handler
  - CODAP export handler

## How to Restore

**IMPORTANT:** The UI tab content was completely removed from `app.R` to avoid syntax errors. To restore these features, you must retrieve the code from git history.

### Retrieving from Git

```bash
# View the last working version before archiving
git show 4249910:app.R > app_with_all_tabs.R

# Or restore specific sections
git show 4249910:app.R | sed -n '482,665p' > air_quality_tab.R
git show 4249910:app.R | sed -n '638,854p' > weather_tab.R
```

Then copy the relevant `tabItem()` sections back into `app.R`.

### Alternative: Use if(FALSE) Wrappers in Server Logic Only

The server logic sections ARE wrapped in `if(FALSE) { ... }` blocks. To restore a feature:

### Step 1: Find Archived Sections
Search `app.R` for: `## ARCHIVED`

You'll find comments like:
```r
## ARCHIVED: Air Quality Tab - Focusing on Water Quality first
## To restore: Remove the if(FALSE) wrapper below
if(FALSE) {
```

### Step 2: Remove the `if(FALSE)` Wrapper

**Before:**
```r
## ARCHIVED: Air Quality Tab
## To restore: Remove the if(FALSE) wrapper below
if(FALSE) {
  # Air Quality tab code here...
} # End if(FALSE) - Air Quality archived
```

**After:**
```r
## Air Quality Tab (RESTORED)
{
  # Air Quality tab code here...
}
```

### Step 3: Restore All Related Sections

To fully restore a feature, you must remove `if(FALSE)` from ALL related sections:

**For Air Quality:**
1. Menu item (line ~180)
2. Tab content (lines ~482-636)
3. Reactive values (lines ~891-899)
4. Server logic (lines ~1383-1723)

**For Weather & Climate:**
1. Menu item (line ~181)
2. Tab content (lines ~638-854)
3. Reactive values (lines ~901-909)
4. Server logic (lines ~1725-2135)

### Step 4: Test Thoroughly

After restoring:
1. Check R syntax: `Rscript -e "parse('app.R')"`
2. Run the app locally: `shiny::runApp()`
3. Test all functionality for the restored feature
4. Test CODAP integration
5. Verify CSV downloads work
6. Check no interference with water quality feature

## Why Features Were Archived

### Benefits of Single-Feature Focus
1. **Simpler testing**: Focus all CODAP integration testing on one data type
2. **Faster iteration**: Fewer variables when debugging
3. **Cleaner documentation**: Can perfect water quality docs first
4. **Better student experience**: One polished feature beats three half-working features
5. **Code preservation**: Everything stays in the codebase, just disabled

### Development Strategy
1. Perfect water quality data collection ✓ (current phase)
2. Perfect water quality CODAP integration (current phase)
3. Comprehensive water quality documentation (current phase)
4. Restore air quality → refine → test
5. Restore weather/climate → refine → test
6. Final integration testing with all three features

## Technical Notes

### Why `if(FALSE)` Instead of Comments?
- **Preserves syntax highlighting** in editors
- **Maintains code structure** (indentation, etc.)
- **Easier to restore** (just remove wrapper)
- **R still validates structure** within the block
- **Single-line toggle** to enable/disable

### Verification
After archiving, the following was verified:
- ✅ R syntax check passed
- ✅ App runs without errors
- ✅ Water quality tab fully functional
- ✅ CODAP integration works
- ✅ CSV download works
- ✅ About tab accessible
- ✅ No orphaned UI elements
- ✅ No server errors from missing reactive values

## Impact on Dependencies

Archived features do NOT require removing packages from installation. All packages remain available:
- `dataRetrieval` (active - used by water quality)
- `RAQSAPI` (dormant - used by air quality)
- `climateR` (dormant - used by weather/climate)

This means restoration is truly just removing `if(FALSE)` wrappers - no reinstallation needed.

## Questions?

See:
- `CLAUDE.md` - Project architecture overview
- `CODAP_INTEGRATION.md` - User guide for CODAP features
- `CODAP_TECHNICAL.md` - Developer reference for CODAP implementation
- `README.md` - User-facing documentation

---

**Last Updated:** 2026-02-16
**Status:** Air Quality and Weather/Climate archived, Water Quality active
**Restoration Estimate:** ~15 minutes per feature (remove wrappers + test)
