# Testing the Shiny App with CODAP - Student Guide

## The Issue You're Experiencing

You're seeing "unknown game" and "127.0.0.1 was unable to connect" when trying to load your local Shiny app in CODAP. This is a **common issue with local development** and has straightforward solutions.

## Why Local Testing Has Problems

### Problem 1: Missing Port Number
When you run `shiny::runApp()`, R shows something like:
```
Listening on http://127.0.0.1:5432
```

You **MUST include the port number** (the `:5432` part) when adding to CODAP. Just `http://127.0.0.1` won't work.

### Problem 2: Mixed Content Blocking
- CODAP runs on **HTTPS** (https://codap.concord.org)
- Your local app runs on **HTTP** (http://127.0.0.1)
- Modern browsers block HTTP content inside HTTPS pages for security

### Problem 3: CORS Restrictions
Local development servers may have Cross-Origin Resource Sharing restrictions that prevent proper communication.

---

## Solution 1: Fix Your Local URL (Quick Test)

### Step-by-Step

1. **Start your Shiny app:**
   ```r
   shiny::runApp("app.R")
   ```

2. **Look at the R console output** - you'll see something like:
   ```
   Listening on http://127.0.0.1:5432
   ```
   **Copy the ENTIRE URL including the port number!**

3. **In CODAP:**
   - Click the **☰ (hamburger menu)** in top left
   - Select **Import Data From** → **Data Interactive**
   - Paste: `http://127.0.0.1:5432` (use YOUR actual port number)
   - Click **Connect**

4. **Enable insecure content (if needed):**

   **Chrome:**
   - Look for a shield icon 🛡️ in the address bar
   - Click it and select "Load unsafe scripts"
   - Or enable `chrome://flags/#allow-insecure-localhost`

   **Firefox:**
   - Click the lock icon in address bar
   - Click "Connection not secure" → "Disable protection for now"

### Expected Behavior

If this works, you should see:
- Your Shiny app loads inside a CODAP panel
- Browser console (F12) shows: `"CODAP interface initialized"`
- You can fetch data and click "Send to CODAP"

---

## Solution 2: Deploy to shinyapps.io (Recommended)

**Local testing is finicky.** For reliable testing, deploy to shinyapps.io:

### Step-by-Step

1. **Install rsconnect (if not already):**
   ```r
   install.packages("rsconnect")
   ```

2. **Set up your shinyapps.io account:**
   - Go to https://www.shinyapps.io/
   - Create a free account
   - Click your name (top right) → **Tokens**
   - Click **Show** → **Copy to clipboard**

3. **Configure rsconnect in R:**
   ```r
   library(rsconnect)
   # Paste the command you copied from shinyapps.io
   # It looks like:
   # rsconnect::setAccountInfo(name="yourname", token="...", secret="...")
   ```

4. **Deploy your app:**
   ```r
   setwd("/Users/jrosenb8/credible-local-data")
   rsconnect::deployApp()
   ```

5. **Get your app URL:**
   After deployment, you'll see:
   ```
   Application successfully deployed to https://yourname.shinyapps.io/credible-local-data/
   ```
   **Copy this URL!**

6. **Add to CODAP:**
   - Open CODAP: https://codap.concord.org/
   - Click **☰** → **Import Data From** → **Data Interactive**
   - Paste: `https://yourname.shinyapps.io/credible-local-data/`
   - Click **Connect**

### Why This Works Better

✅ **HTTPS by default** - No mixed content issues
✅ **Publicly accessible** - No CORS problems
✅ **Stable URL** - Doesn't change between sessions
✅ **Shareable** - Others can test too

---

## Testing Checklist

Once your app loads in CODAP (either local or deployed), test this:

### 1. Visual Check
- [ ] Your Shiny app appears inside a CODAP panel
- [ ] Browser URL shows `codap.concord.org` (not your app URL)
- [ ] All three tabs are visible (Water Quality, Air Quality, Weather)

### 2. Console Check (F12)
Open browser console and verify:
- [ ] `"CODAP interface initialized"` appears
- [ ] No red error messages
- [ ] `window === window.parent` returns `false` (means you're in an iframe)

### 3. Functional Test - Water Quality
- [ ] Select State: Tennessee
- [ ] Select County: Knox
- [ ] Click "Fetch Water Quality Data"
- [ ] Wait for data to load
- [ ] Data preview table shows results
- [ ] Enter dataset name (e.g., "KnoxWater")
- [ ] Click "Send to CODAP"

### 4. Check Console Output
After clicking "Send to CODAP", you should see:
```javascript
Received sendToCODAP message from Shiny: {...}
Current window location: ...
Parent window exists: true
CODAP API available: true
Dataset name: KnoxWater
Number of attributes: X
Number of cases: Y
Sending to CODAP: {action: "create", resource: "dataContext", ...}
DataContext created successfully: {...}
Cases sent successfully: {...}
Total cases sent: Y
```

### 5. Check CODAP
- [ ] New dataset appears in CODAP (look for table icon)
- [ ] Dataset name matches what you entered
- [ ] All columns from your data are present
- [ ] All rows are present
- [ ] Data values are correct

### 6. Test Other Tabs
Repeat for:
- [ ] Air Quality tab (note: demo mode, limited data)
- [ ] Weather & Climate tab

---

## Common Errors and Solutions

### Error: "CODAP interface not available"

**Cause:** The `codapInterface` function is not defined.

**Solution:** Make sure you're running the actual `app.R` file, not a simplified version. The file should have lines 191-317 with the complete JavaScript code.

**Check:** Open `app.R` and search for `function codapInterface` - it should be there around line 197.

### Error: "Not running inside CODAP"

**Cause:** You opened your app URL directly instead of embedding it in CODAP.

**Solution:**
- Don't visit your app URL directly in a browser
- Must load CODAP first (https://codap.concord.org)
- Then add your app URL through CODAP's import menu

### Error: "CODAP request timeout"

**Cause:** CODAP isn't responding to API calls.

**Solutions:**
1. Check browser console for actual error
2. Verify you're using latest CODAP (https://codap.concord.org, not an old cached version)
3. Try different browser (Chrome or Firefox recommended)
4. Clear browser cache and try again

### Error: "unknown game" / "unable to connect"

**Cause:** (Your current issue) URL is incomplete or inaccessible.

**Solutions:**
1. **For local:** Include full URL with port: `http://127.0.0.1:XXXX`
2. **For local:** Enable insecure content in browser (see Solution 1 above)
3. **Better:** Deploy to shinyapps.io and use HTTPS URL (see Solution 2 above)

---

## Debugging Tips

### 1. Check if Shiny App is Running

In your R console, you should see:
```
Listening on http://127.0.0.1:XXXX
```

If you don't see this, your app isn't running.

### 2. Test Shiny App Standalone First

Before embedding in CODAP:
1. Visit your app URL directly in a browser
2. Make sure it loads and works
3. Try fetching data
4. Try clicking "Download as CSV" (should work)
5. Only then try "Send to CODAP" (will show error message, but proves app works)

### 3. Check Browser Console

**Always have console open (F12)** when testing CODAP integration:
- **Red errors:** Something is broken
- **Yellow warnings:** Usually okay, just informational
- **Blue logs:** Normal operation

### 4. Verify You're Embedded

In browser console, type:
```javascript
window === window.parent
```

- Returns `true` → **NOT embedded** (you're viewing app directly)
- Returns `false` → **Embedded** (you're in CODAP iframe) ✓

---

## Quick Reference: The Right Way to Test

### ❌ WRONG: Direct Access
```
1. Open browser
2. Go to http://127.0.0.1:5432
3. Try clicking "Send to CODAP"
→ ERROR: "Not running inside CODAP"
```

### ✅ RIGHT: Embedded in CODAP
```
1. Run shiny::runApp() in R
2. Note the URL with port: http://127.0.0.1:5432
3. Open new tab → https://codap.concord.org
4. In CODAP: ☰ → Import Data From → Data Interactive
5. Paste: http://127.0.0.1:5432
6. Enable insecure content if prompted
7. App loads inside CODAP panel
8. Now "Send to CODAP" works!
```

### ✅ BEST: Deployed Version
```
1. Deploy: rsconnect::deployApp()
2. Copy URL: https://yourname.shinyapps.io/credible-local-data/
3. Open: https://codap.concord.org
4. In CODAP: ☰ → Import Data From → Data Interactive
5. Paste deployed URL
6. Works perfectly, no browser security issues!
```

---

## Next Steps for Your Project

1. **Get it working locally first:**
   - Include the port number in your URL
   - Enable insecure content
   - Verify console shows success messages

2. **Deploy to shinyapps.io:**
   - More reliable for testing
   - Can share with others
   - No browser security issues

3. **Test all three data types:**
   - Water quality (should work well)
   - Air quality (demo mode)
   - Weather (should work well)

4. **Document what works:**
   - Take screenshots of successful data transfer
   - Note any issues you find
   - Try with different datasets and counties

5. **Share your deployed URL:**
   - Your instructor can test it
   - Classmates can try it
   - Include in your project documentation

---

## Help Resources

- **This project's docs:**
  - `CODAP_INTEGRATION.md` - Full user guide
  - `CODAP_TECHNICAL.md` - Developer reference

- **CODAP:**
  - Website: https://codap.concord.org
  - API Docs: https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API

- **shinyapps.io:**
  - Website: https://www.shinyapps.io
  - Documentation: https://docs.rstudio.com/shinyapps.io/

---

## Summary

**Your current issue:** Missing port number in URL and HTTP/HTTPS mismatch

**Quick fix:** Use `http://127.0.0.1:XXXX` with the actual port number and enable insecure content

**Best fix:** Deploy to shinyapps.io and use the HTTPS URL

**The app code is fine** - the JavaScript in `app.R` is complete and correct. This is purely a connection/deployment issue, not a code issue.

Good luck with your testing! 🎉
