# How to Use Your Shiny App with CODAP

## The Issue: "CODAP request timeout" Error

If you're seeing this error, it means your Shiny app is **not embedded inside CODAP**. The "Send to CODAP" feature only works when the app is running as a Data Interactive **inside** CODAP.

## ✅ Solution: Embed Your App in CODAP

Your app needs to run **inside** CODAP as a Data Interactive, not as a standalone app.

---

## Step-by-Step Setup Guide

### Step 1: Deploy Your Shiny App (If Not Already)

Your app needs a public URL. Options:

**Option A: shinyapps.io (Recommended)**
```r
# In R Console
library(rsconnect)
rsconnect::deployApp()
```
This will give you a URL like: `https://your-username.shinyapps.io/credible-local-data/`

**Option B: Local Development**
- Run your app locally: `shiny::runApp()`
- Note the URL (e.g., `http://127.0.0.1:7123`)
- ⚠️ Local URLs only work for testing on the same computer

### Step 2: Open CODAP

Go to: **https://codap.concord.org/**

### Step 3: Add Your App as a Data Interactive

**Method 1: Using Plugins Menu**
1. In CODAP, click the **ruler/wrench icon** (top right)
2. Select **Plugins** or **Manage Data Interactives**
3. Click **+ Add Plugin** or **Configure Plugin**
4. Enter your Shiny app URL
5. Click **Apply** or **Add**

**Method 2: Using Web View**
1. In CODAP, drag the **Web View** component from the toolbar
2. In the Web View settings, enter your Shiny app URL
3. The app will load inside CODAP

**Method 3: Using Import Menu**
1. Click **Tables** menu (top bar)
2. Select **Import Data From** → **Data Interactive**
3. Enter your app URL
4. Click **Connect**

### Step 4: Verify It's Working

Once embedded, you should see:

1. Your Shiny app loads **inside** a CODAP frame
2. In browser console (F12), you should see:
   ```
   CODAP interface initialized
   ```
3. When you click "Send to CODAP", the data should appear as a new dataset in CODAP

---

## Common Issues & Solutions

### Issue 1: "Not running inside CODAP" Error

**Symptom:**
```
CODAP Export Error: This app must be embedded in CODAP to use 
the "Send to CODAP" feature.
```

**Solution:**
- Don't open your app directly in a browser tab
- Must be embedded inside CODAP as shown in Step 3 above
- The app needs to be in an iframe/frame within CODAP

### Issue 2: "CODAP request timeout"

**Symptom:**
```
CODAP Export Error: CODAP did not respond within 10 seconds.
```

**Possible Causes:**
1. **Not properly embedded** - See Step 3 above
2. **Wrong CODAP version** - Use https://codap.concord.org/ (not an old version)
3. **Browser blocking postMessage** - Check browser console for security errors
4. **CORS issues** - Make sure your app URL is publicly accessible

**Solution:**
- Verify you're using the latest CODAP version
- Check browser console (F12) for any security errors
- Try a different browser (Chrome or Firefox recommended)

### Issue 3: App Won't Load in CODAP

**Symptom:** Blank frame or error message when trying to load your app

**Possible Causes:**
1. **URL not accessible** - App not deployed or not public
2. **HTTP vs HTTPS mismatch** - CODAP uses HTTPS, your app might need HTTPS too
3. **X-Frame-Options blocking** - Some hosting services block iframe embedding

**Solution for shinyapps.io:**
shinyapps.io should work fine - it allows iframe embedding and uses HTTPS.

**Solution for other hosts:**
Make sure your hosting service:
- Allows iframe embedding
- Uses HTTPS
- Doesn't set restrictive X-Frame-Options headers

### Issue 4: Data Doesn't Appear in CODAP

**Symptom:** No error, but dataset doesn't show up in CODAP

**Solution:**
1. Check browser console (F12) for any JavaScript errors
2. Look for CODAP response messages in console
3. Try with a small dataset first (< 100 rows)
4. Verify your data has no unusual characters or invalid values

---

## Testing Your Setup

### Quick Test Checklist

1. ✅ **Deploy app** to shinyapps.io
2. ✅ **Open CODAP** at https://codap.concord.org/
3. ✅ **Add your app** as a Data Interactive
4. ✅ **Fetch some data** in your app (e.g., Knox County, Tennessee water quality)
5. ✅ **Click "Send to CODAP"**
6. ✅ **Check browser console** (F12) - should see success messages
7. ✅ **Verify dataset appears** in CODAP

### Expected Console Output (Success)

When working correctly, you should see:
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Sending to CODAP: {action: "create", resource: "dataContext", ...}
DataContext created successfully: {...}
Cases sent successfully: {...}
Total cases sent: 123
```

### Expected Console Output (Not in CODAP)

If running standalone:
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Not running inside CODAP - no parent frame detected
Error sending data to CODAP: {error: "Not running in CODAP", ...}
```

---

## Visual Diagram

### ❌ Wrong Way (Standalone)
```
┌─────────────────────────────────────┐
│  Browser Tab                        │
│  ┌───────────────────────────────┐  │
│  │ Your Shiny App                │  │
│  │ (Direct URL)                  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         ↓
   ⚠️ "Not running inside CODAP" error
```

### ✅ Right Way (Embedded)
```
┌─────────────────────────────────────────────┐
│  Browser Tab: CODAP                         │
│  ┌───────────────────────────────────────┐  │
│  │  CODAP Interface                      │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │ Your Shiny App (in iframe)      │  │  │
│  │  │ [Data Interactive]              │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
         ↓
   ✅ "Send to CODAP" works perfectly!
```

---

## Alternative: Download as CSV

If you can't embed in CODAP or just want to download the data:

1. Use the **"Download as CSV"** button instead
2. Download the CSV file
3. In CODAP, use **Tables → Import from → CSV File**
4. Select your downloaded file

This doesn't require the Data Interactive API, but you lose the seamless one-click export.

---

## Development/Testing Workflow

### For Local Testing

1. **Run your app locally:**
   ```r
   shiny::runApp()
   # Note the URL, e.g., http://127.0.0.1:7123
   ```

2. **Open CODAP locally** (if you have it) or use https://codap.concord.org/

3. **Add your local URL** as a Data Interactive
   - ⚠️ Some browsers may block mixed content (HTTP in HTTPS CODAP)
   - Use Chrome with: `chrome://flags/#allow-insecure-localhost`

### For Production

1. **Deploy to shinyapps.io:**
   ```r
   library(rsconnect)
   rsconnect::deployApp()
   ```

2. **Use the production URL** in CODAP:
   ```
   https://your-username.shinyapps.io/credible-local-data/
   ```

3. **Share the CODAP document** with your URL embedded

---

## Sharing with Users

### Option 1: Share CODAP Document
1. Set up your app in CODAP as shown above
2. Save the CODAP document (File → Save)
3. Share the CODAP document URL with users
4. They open the CODAP document, and your app is already embedded!

### Option 2: Share Instructions
Provide users with:
1. Your app URL (e.g., `https://username.shinyapps.io/credible-local-data/`)
2. Instructions to add it to CODAP (see Step 3 above)

---

## Further Help

### CODAP Resources
- **CODAP Website:** https://codap.concord.org/
- **CODAP Documentation:** https://github.com/concord-consortium/codap/wiki
- **Data Interactive API:** https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API

### Debugging Tips

1. **Always check browser console** (F12) for error messages
2. **Test with small datasets first** before trying large ones
3. **Verify app works standalone** before embedding in CODAP
4. **Use Chrome or Firefox** for best compatibility
5. **Check CORS policies** if having loading issues

### Still Having Issues?

If you're still stuck:
1. Check that your app URL is publicly accessible
2. Try the CSV download method as a backup
3. Verify you're using the latest CODAP version
4. Check that your browser allows postMessage between frames
5. Look for any JavaScript errors in the console

---

**Remember:** The "Send to CODAP" feature ONLY works when your app is embedded inside CODAP as a Data Interactive. For standalone use, use the "Download as CSV" button instead.


