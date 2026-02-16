# CODAP Integration Guide

This guide explains how to use the CREDIBLE Local Data Shiny app with CODAP (Common Online Data Analysis Platform) for seamless data export and interactive analysis.

## Table of Contents
- [Quick Start](#quick-start)
- [Understanding CODAP Integration](#understanding-codap-integration)
- [Deployment Options](#deployment-options)
- [Embedding Your App in CODAP](#embedding-your-app-in-codap)
- [Testing Your Setup](#testing-your-setup)
- [Troubleshooting](#troubleshooting)
- [Alternative: CSV Download](#alternative-csv-download)

---

## Quick Start

**The 3-Step Solution:**

1. **Deploy Your App**
   ```r
   library(rsconnect)
   rsconnect::deployApp()
   ```
   Result: `https://username.shinyapps.io/credible-local-data/`

2. **Open CODAP**
   Go to: https://codap.concord.org/

3. **Add Your App to CODAP**
   - Click **wrench/ruler icon** (top right)
   - Select **"Plugins"** or **"Manage Data Interactives"**
   - Paste your app URL
   - Click **"Add"**

**Now it works!** Your app is inside CODAP and "Send to CODAP" will work.

---

## Understanding CODAP Integration

### What is CODAP?
CODAP (Common Online Data Analysis Platform) is an interactive data analysis tool designed for education. Your Shiny app can send data directly to CODAP for student analysis.

### How It Works
The app includes three "Send to CODAP" buttons (one per data type: water quality, air quality, weather). These buttons:
- Only work when the app is **embedded inside CODAP** as a Data Interactive
- Use the CODAP Data Interactive Plugin API to communicate via `postMessage`
- Create new datasets in CODAP with your fetched data

### Important Requirement
**The "Send to CODAP" feature ONLY works when your app is embedded inside CODAP.** If you run the app standalone (in its own browser tab), you'll see a timeout error. This is expected behavior.

### Visual Comparison

**❌ Standalone (Doesn't Work)**
```
┌──────────────────────────────┐
│ Browser Tab                  │
│ URL: your-app.shinyapps.io  │ ← App URL in address bar
│                              │
│  ┌────────────────────────┐  │
│  │ Your Shiny App         │  │
│  │ [Send to CODAP] ❌    │  │ ← Gets timeout error
│  └────────────────────────┘  │
└──────────────────────────────┘
```

**✅ Embedded in CODAP (Works!)**
```
┌────────────────────────────────────────┐
│ Browser Tab                            │
│ URL: codap.concord.org                 │ ← CODAP URL in address bar
│                                        │
│  ┌────────────────────────────────┐    │
│  │ CODAP Interface                │    │
│  │  ┌──────────────────────────┐  │    │
│  │  │ Your Shiny App (iframe)  │  │    │
│  │  │ [Send to CODAP] ✅      │  │    │ ← Works perfectly!
│  │  └──────────────────────────┘  │    │
│  │                                │    │
│  │ 📊 Datasets                    │    │
│  │   - WaterQualityData          │    │ ← Data appears here
│  └────────────────────────────────┘    │
└────────────────────────────────────────┘
```

---

## Deployment Options

Your app needs a URL that CODAP can access. Choose one:

### Option A: shinyapps.io (Recommended for Production)

**Pros:**
- Free tier available
- HTTPS by default
- Allows iframe embedding
- Publicly accessible

**Deployment:**
```r
# In R Console
library(rsconnect)
rsconnect::deployApp()
```

This gives you: `https://your-username.shinyapps.io/credible-local-data/`

### Option B: Local Development (Testing Only)

**Pros:**
- No deployment needed
- Good for development

**Cons:**
- Only works on your computer
- May have mixed content issues (HTTP in HTTPS CODAP)

**Usage:**
```r
shiny::runApp()
# Note the URL: http://127.0.0.1:XXXX
```

**Browser Setup for Local Testing:**
- Chrome: Enable `chrome://flags/#allow-insecure-localhost`
- Or use local CODAP installation if available

### Option C: Other Hosting

If using custom hosting, ensure:
- HTTPS enabled
- iframe embedding allowed (no restrictive `X-Frame-Options` headers)
- CORS properly configured

---

## Embedding Your App in CODAP

Once you have your app URL, add it to CODAP using one of these methods:

### Method 1: Plugins Menu (Recommended)

1. In CODAP, click the **ruler/wrench icon** (top right)
2. Select **"Plugins"** or **"Manage Data Interactives"**
3. Click **"+ Add Plugin"** or **"Configure Plugin"**
4. Enter your Shiny app URL
5. Click **"Apply"** or **"Add"**

Your app loads in a panel within CODAP.

### Method 2: Web View Component

1. Drag the **"Web View"** component from the CODAP toolbar onto the canvas
2. In the Web View settings, enter your Shiny app URL
3. Your app loads inside the Web View

### Method 3: Import Menu

1. Click **"Tables"** menu (top bar)
2. Select **"Import Data From"** → **"Data Interactive"**
3. Enter your app URL
4. Click **"Connect"**

---

## Testing Your Setup

### Quick Test Checklist

1. ✅ Deploy app to shinyapps.io
2. ✅ Open CODAP at https://codap.concord.org/
3. ✅ Add your app as a Data Interactive (see methods above)
4. ✅ Verify your app loads inside CODAP
5. ✅ Fetch some data in your app (e.g., Knox County, Tennessee water quality)
6. ✅ Click "Send to CODAP"
7. ✅ Check browser console (F12) - should see success messages
8. ✅ Verify dataset appears in CODAP

### Expected Console Output

**✅ Success (Embedded in CODAP):**
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Sending to CODAP: {action: "create", resource: "dataContext", ...}
DataContext created successfully: {...}
Cases sent successfully: {...}
Total cases sent: 123
```

**❌ Error (Not Embedded):**
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Not running inside CODAP - no parent frame detected
Error sending data to CODAP: {error: "Not running in CODAP", ...}
```

### How to Tell If It's Working

| Indicator | ✅ Working (Embedded) | ❌ Not Working (Standalone) |
|-----------|---------------------|----------------------------|
| Browser URL | `codap.concord.org` | `your-app.shinyapps.io` |
| App location | Inside CODAP frame | Own browser tab |
| Send to CODAP | Data appears in CODAP | Timeout error |
| Console | Success messages | "Not running inside CODAP" |

---

## Troubleshooting

### Issue 1: "Not running inside CODAP" Error

**Symptom:**
```
CODAP Export Error: This app must be embedded in CODAP to use
the "Send to CODAP" feature.
```

**Cause:** Your app is running in its own browser tab, not embedded in CODAP.

**Solution:**
- Don't open your app URL directly in a browser
- Follow the [embedding instructions](#embedding-your-app-in-codap) above
- Check that your browser URL shows `codap.concord.org`, not your app URL

### Issue 2: "CODAP request timeout"

**Symptom:**
```
CODAP Export Error: CODAP did not respond within 10 seconds.
```

**Possible Causes & Solutions:**

1. **Not properly embedded**
   - Verify you're using one of the embedding methods above
   - Check browser URL shows `codap.concord.org`

2. **Wrong CODAP version**
   - Use the latest: https://codap.concord.org/
   - Avoid old/cached versions

3. **Browser blocking postMessage**
   - Open browser console (F12) and look for security errors
   - Try Chrome or Firefox (recommended browsers)
   - Clear browser cache

4. **CORS issues**
   - Ensure your app URL is publicly accessible
   - Check hosting service allows cross-origin requests

### Issue 3: App Won't Load in CODAP

**Symptom:** Blank frame or loading error when trying to embed your app

**Possible Causes & Solutions:**

1. **URL not accessible**
   - Verify app is deployed and running
   - Test the URL in a regular browser tab first

2. **HTTP vs HTTPS mismatch**
   - CODAP uses HTTPS
   - Your app should also use HTTPS (shinyapps.io does this automatically)

3. **iframe embedding blocked**
   - Check hosting service allows iframe embedding
   - Look for `X-Frame-Options` headers blocking embedding

**For shinyapps.io users:** This should work out of the box.

### Issue 4: Data Doesn't Appear in CODAP

**Symptom:** No error, but dataset doesn't show up

**Solution:**
1. Open browser console (F12) and look for JavaScript errors
2. Check for CODAP response messages in console
3. Try with a small dataset first (< 100 rows)
4. Verify data has no unusual characters or invalid values
5. Make sure you fetched data before clicking "Send to CODAP"

### Issue 5: Embedded But Still Timing Out

**Advanced Debugging:**

1. **Verify iframe detection:**
   - Open console (F12)
   - Type: `window === window.parent`
   - Should return `false` if properly embedded
   - If `true`, app is not in an iframe

2. **Check postMessage communication:**
   - Look for console messages about sending/receiving
   - Verify no CORS or security errors
   - Try a different browser

3. **CODAP version check:**
   - Ensure you're using the latest CODAP
   - Old versions may have API incompatibilities

4. **Test with minimal data:**
   - Fetch just a few rows
   - See if small datasets work (rules out data size issues)

### Debugging Checklist

- [ ] Check URL bar shows `codap.concord.org`
- [ ] Open browser console (F12) for error messages
- [ ] Verify app loads inside CODAP frame
- [ ] Look for CORS errors in console
- [ ] Try different browser (Chrome/Firefox)
- [ ] Clear browser cache
- [ ] Test with latest CODAP version
- [ ] Try with small dataset (< 100 rows)
- [ ] Verify `window === window.parent` returns `false`

---

## Alternative: CSV Download

If you can't embed in CODAP or prefer manual import:

### Workflow

1. **In your Shiny app:** Click **"Download as CSV"**
2. **Save the file** to your computer
3. **In CODAP:**
   - **"Tables"** menu → **"Import from"** → **"CSV File"**
   - Select your downloaded file
   - Data imports into CODAP

This doesn't use the Data Interactive API, but achieves the same result.

---

## Sharing with Users

### Option 1: Share CODAP Document

1. Set up your app in CODAP as described above
2. Save the CODAP document: **File** → **Save**
3. Share the CODAP document URL with users
4. When they open it, your app is already embedded!

### Option 2: Share Instructions

Provide users with:
1. Your app URL (e.g., `https://username.shinyapps.io/credible-local-data/`)
2. Instructions to add it to CODAP (link to this guide)

---

## Additional Resources

### CODAP Resources
- **CODAP Website:** https://codap.concord.org/
- **CODAP Documentation:** https://github.com/concord-consortium/codap/wiki
- **Data Interactive API:** https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API

### Project Documentation
- **Technical Details:** See `CODAP_TECHNICAL.md` for developer reference
- **UI Changes:** See `UI_CHANGES_VISUAL_GUIDE.md` for visual layouts

### Debugging Tips
1. Always check browser console (F12) for error messages
2. Test with small datasets first before trying large ones
3. Verify app works standalone before embedding in CODAP
4. Use Chrome or Firefox for best compatibility
5. Check CORS policies if having loading issues

---

**Remember:** The "Send to CODAP" feature ONLY works when your app is embedded inside CODAP as a Data Interactive. For standalone use, use the "Download as CSV" button instead.
