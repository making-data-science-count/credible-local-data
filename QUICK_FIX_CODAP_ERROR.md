# Quick Fix: CODAP Timeout Error ⚡

## The Problem
```
❌ CODAP Export Error: CODAP request timeout
```

## The Cause
Your app is running **standalone** (in its own browser tab) instead of **embedded inside CODAP**.

## The Solution (3 Steps)

### 1️⃣ Deploy Your App
```r
library(rsconnect)
rsconnect::deployApp()
```
**Result:** You get a URL like `https://username.shinyapps.io/credible-local-data/`

### 2️⃣ Open CODAP
Go to: **https://codap.concord.org/**

### 3️⃣ Add Your App to CODAP
- Click **wrench/ruler icon** (top right)
- Select **"Plugins"** or **"Manage Data Interactives"**
- Paste your app URL
- Click **"Add"**

## ✅ Now It Works!
Your app is now **inside** CODAP, and "Send to CODAP" will work!

---

## Alternative: Download CSV Instead

Can't embed right now? Use this:

1. Click **"Download as CSV"** in your app
2. In CODAP: **Tables → Import from → CSV File**
3. Select your downloaded file

---

## How to Tell If It's Fixed

### ❌ Before (Not Working)
- Browser URL: `your-app.shinyapps.io`
- App in own tab
- Timeout error

### ✅ After (Working!)
- Browser URL: `codap.concord.org`
- App inside CODAP frame
- Data appears in CODAP!

---

## Still Having Issues?

See the detailed guide: **`HOW_TO_USE_WITH_CODAP.md`**

Or check console (F12) for error messages.

---

**Remember:** "Send to CODAP" ONLY works when embedded in CODAP!


