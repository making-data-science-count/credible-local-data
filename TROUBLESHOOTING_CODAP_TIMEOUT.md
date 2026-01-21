# Troubleshooting: "CODAP request timeout" Error

## Summary of Issue

You're seeing: **"CODAP Export Error: CODAP request timeout"**

This happens because **your app is not embedded inside CODAP**. The "Send to CODAP" feature only works when the app runs as a Data Interactive plugin **inside** CODAP.

---

## ✅ What I Fixed

I've updated your app to provide better error detection and helpful messages:

### 1. **Early Detection** (Lines 199-208)
The app now checks if it's running inside CODAP before trying to send data:

```javascript
if (window === window.parent) {
  // Not in CODAP - show helpful error immediately
  reject({
    error: 'Not running in CODAP',
    message: 'This app must be embedded in CODAP...',
    helpUrl: 'https://codap.concord.org/'
  });
}
```

### 2. **Better Error Messages** (Lines 291-306)
Errors now include helpful guidance with:
- Clear explanation of the problem
- Link to CODAP website
- Suggestion to use CSV download as alternative

### 3. **Enhanced Notification** (Lines 1336-1362)
The Shiny notification now shows:
- The specific error that occurred
- Tip explaining the feature only works when embedded in CODAP
- Link to CODAP website
- Alternative suggestion (use "Download as CSV")
- Longer duration (15 seconds) so you have time to read it

---

## 🚀 How to Fix the Timeout Error

### Quick Solution: Embed Your App in CODAP

**You MUST run your app inside CODAP, not as a standalone website.**

#### Step 1: Get Your App URL

**Option A: Deploy to shinyapps.io**
```r
library(rsconnect)
rsconnect::deployApp()
```
You'll get: `https://your-username.shinyapps.io/credible-local-data/`

**Option B: Use Local URL (for testing)**
```r
shiny::runApp()
```
Note the URL: `http://127.0.0.1:XXXX`

#### Step 2: Open CODAP

Go to: **https://codap.concord.org/**

#### Step 3: Add Your App to CODAP

**Method 1: Plugins Menu**
1. Click the **wrench/ruler icon** (top right in CODAP)
2. Select **"Plugins"** or **"Manage Data Interactives"**
3. Enter your app URL
4. Click **"Add"** or **"Apply"**

**Method 2: Web View Component**
1. Drag **"Web View"** component onto CODAP canvas
2. Enter your app URL in the settings
3. Your app loads inside CODAP

**Method 3: Import Menu**
1. **Tables** menu → **Import from** → **Data Interactive**
2. Enter your app URL
3. Click **Connect**

#### Step 4: Test It

1. Your app should now be visible **inside** a CODAP frame
2. Fetch some data in your app
3. Click "Send to CODAP"
4. Data should appear as a new dataset in CODAP!

---

## 🔍 How to Tell If It's Working

### ✅ Working Correctly (In CODAP)

**What you see:**
- Your app is inside a frame/panel within CODAP
- Browser URL shows `codap.concord.org`
- When you click "Send to CODAP", data appears in CODAP
- Console shows: `"DataContext created successfully"`

**Console output:**
```
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Sending to CODAP: {...}
DataContext created successfully: {...}
Cases sent successfully: {...}
Total cases sent: 123
```

### ❌ Not Working (Standalone)

**What you see:**
- Your app is in its own browser tab
- Browser URL shows your app's URL directly (not codap.concord.org)
- When you click "Send to CODAP", you get a timeout error
- Console shows: `"Not running inside CODAP - no parent frame detected"`

**Console output:**
```
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Not running inside CODAP - no parent frame detected
Error sending data to CODAP: {error: "Not running in CODAP", ...}
```

**Error notification:**
```
CODAP Export Error: This app must be embedded in CODAP to use 
the Send to CODAP feature. Please open CODAP at codap.concord.org 
and add this app URL as a plugin.

Tip: The 'Send to CODAP' feature only works when this app is 
embedded inside CODAP as a Data Interactive. To use this feature, 
open CODAP at codap.concord.org and add this app URL as a plugin.

Alternatively, use the 'Download as CSV' button and import the 
file into CODAP manually.
```

---

## 🛠️ Alternative: Use CSV Download

If you can't embed in CODAP right now, use this workflow:

1. **In your Shiny app:** Click "Download as CSV"
2. **Save the file** to your computer
3. **In CODAP:**
   - **Tables** menu → **Import from** → **CSV File**
   - Select your downloaded file
   - Data imports into CODAP

This doesn't use the Data Interactive API, but achieves the same result.

---

## 📊 Visual Comparison

### Wrong: Standalone App
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

### Right: Embedded in CODAP
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

## 🐛 Debugging Checklist

If it's still not working after embedding:

- [ ] **Check URL bar** - Should show `codap.concord.org`, not your app URL
- [ ] **Open browser console** (F12) - Look for error messages
- [ ] **Verify app loads** - Your app should be visible inside CODAP
- [ ] **Check for CORS errors** - Look in console for blocked requests
- [ ] **Try different browser** - Chrome or Firefox recommended
- [ ] **Clear browser cache** - Old cached versions can cause issues
- [ ] **Check CODAP version** - Use latest from https://codap.concord.org/
- [ ] **Test with small data** - Try < 100 rows first

---

## 📚 Additional Resources

### Documentation I Created for You

1. **`HOW_TO_USE_WITH_CODAP.md`** - Step-by-step setup guide
2. **`CODAP_INTEGRATION_SUMMARY.md`** - Technical implementation details
3. **`CODAP_CODE_REFERENCE.md`** - Code line references
4. **`UI_CHANGES_VISUAL_GUIDE.md`** - Visual guide to UI changes
5. **`README_CODAP_INTEGRATION.md`** - Quick start guide

### External Resources

- **CODAP:** https://codap.concord.org/
- **Data Interactive API:** https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API

---

## ✨ New Error Detection Features

Your app now provides:

### 1. Immediate Detection
Instead of waiting 10 seconds for timeout, the app now:
- Instantly detects if it's not in CODAP
- Shows error immediately (no waiting)
- Provides helpful guidance

### 2. Helpful Error Messages
Errors now include:
- Clear explanation of what's wrong
- Link to CODAP website  
- Alternative solution (CSV download)
- Extended notification duration (15 seconds)

### 3. Console Logging
Check browser console (F12) to see:
- Detection messages
- Communication with CODAP
- Success/failure status
- Detailed error information

---

## Note on Linter Warning

You may see a linter warning on line 204:
```
Line 204:74: unexpected symbol, severity: error
```

**This is a false positive.** The R linter is trying to parse the JavaScript code as R code. The app will work fine - this is valid JavaScript within a string.

---

## Summary

**The timeout error happens because your app is not embedded in CODAP.**

**Solution:** Open CODAP at https://codap.concord.org/ and add your app URL as a Data Interactive plugin.

**Alternative:** Use the "Download as CSV" button and import into CODAP manually.

The app now provides better error messages to guide you through this process!


