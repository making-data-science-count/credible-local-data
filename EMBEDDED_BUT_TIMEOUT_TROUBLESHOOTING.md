# Troubleshooting: App Embedded in CODAP But Getting Timeout

## The Issue

You've successfully embedded your Shiny app in CODAP (✅ you can see the CODAP interface), but when you click "Send to CODAP", you get:

```
❌ CODAP Export Error: CODAP did not respond within 10 seconds. 
Make sure this app is properly embedded in CODAP as a Data Interactive.
```

## Why This Happens

Even though your app is embedded in CODAP, the **Data Interactive Plugin API communication** isn't working. This can happen for several reasons:

1. **Wrong embedding method** - Not using Data Interactive plugin
2. **CODAP version compatibility** - Using an older CODAP version
3. **Browser security** - CORS or postMessage restrictions
4. **Plugin configuration** - Incorrect setup

---

## 🔧 Step-by-Step Troubleshooting

### Step 1: Check Browser Console

**Open browser console (F12)** and look for these messages when you click "Send to CODAP":

#### ✅ Good Signs:
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Current window location: https://codap.concord.org/...
Parent window exists: true
CODAP API available: true
Sending to CODAP: {...}
```

#### ❌ Bad Signs:
```javascript
CODAP interface initialized
Received sendToCODAP message from Shiny: {...}
Current window location: https://your-app.shinyapps.io/...  ← Wrong!
Parent window exists: false  ← Wrong!
CODAP API available: false  ← Wrong!
```

### Step 2: Verify Embedding Method

**❌ Wrong: Web View Component**
- If you dragged a "Web View" component and pasted your URL
- This creates an iframe but doesn't enable the Data Interactive API
- **Solution:** Remove and use the proper plugin method below

**✅ Correct: Data Interactive Plugin**
1. Click the **wrench/ruler icon** (top right in CODAP)
2. Select **"Plugins"** or **"Manage Data Interactives"**
3. Click **"+ Add Plugin"** or **"Configure Plugin"**
4. Enter your app URL
5. Click **"Apply"** or **"Add"**

### Step 3: Check CODAP Version

Make sure you're using the **latest CODAP**:
- Go to: **https://codap.concord.org/**
- Don't use any bookmarked old versions
- Clear browser cache if needed

### Step 4: Try Different Browser

Some browsers have stricter security policies:
- **Try Chrome** (recommended)
- **Try Firefox**
- Avoid Safari (can have iframe restrictions)

### Step 5: Check Your App URL

Your app URL should be:
- **HTTPS** (not HTTP) - CODAP requires secure connections
- **Publicly accessible** - Test by opening the URL in a new tab
- **No authentication required** - The URL should load without login

---

## 🚀 Quick Fixes to Try

### Fix 1: Re-embed as Data Interactive Plugin

1. **Remove current embedding** (delete the web view component)
2. **Add as plugin:**
   - Wrench icon → Plugins → Add Plugin
   - Enter your app URL
   - Click Add
3. **Test again**

### Fix 2: Refresh Everything

1. **Refresh CODAP page** (Ctrl+F5 or Cmd+Shift+R)
2. **Clear browser cache**
3. **Try again**

### Fix 3: Check URL Format

Make sure your app URL is:
```
✅ https://username.shinyapps.io/credible-local-data/
❌ http://127.0.0.1:7123  (local won't work with CODAP)
❌ https://username.shinyapps.io/credible-local-data  (missing trailing slash)
```

### Fix 4: Test with Small Dataset

Try with a very small dataset first:
1. **Fetch minimal data** (1-2 rows)
2. **Click "Send to CODAP"**
3. **Check if it works**

---

## 🔍 Advanced Debugging

### Check Console Messages

Look for these specific messages in browser console:

```javascript
// Should see this:
"CODAP interface initialized"

// When you click Send to CODAP:
"Received sendToCODAP message from Shiny: {...}"
"Current window location: https://codap.concord.org/..."
"Parent window exists: true"
"CODAP API available: true"
"Sending to CODAP: {action: 'create', resource: 'dataContext', ...}"

// If it works, you'll see:
"DataContext created successfully: {...}"
"Cases sent successfully: {...}"
"Total cases sent: 123"
```

### Check for Security Errors

Look for errors like:
- `Blocked a frame with origin "..." from accessing a cross-origin frame`
- `postMessage` security errors
- CORS errors

### Check Network Tab

In browser DevTools:
1. Go to **Network** tab
2. Click "Send to CODAP"
3. Look for failed requests or blocked messages

---

## 🆘 Alternative Solutions

### Option 1: Use CSV Download

If the Data Interactive API continues to not work:

1. **Click "Download as CSV"** in your app
2. **Save the file**
3. **In CODAP:** Tables → Import from → CSV File
4. **Select your downloaded file**

This achieves the same result without the API.

### Option 2: Try Different CODAP Instance

Sometimes CODAP instances can have issues:
1. **Try a different CODAP document**
2. **Create a new CODAP document**
3. **Embed your app in the new document**

### Option 3: Check CODAP Status

- CODAP might be having server issues
- Try again later
- Check CODAP's status page if available

---

## 📋 Troubleshooting Checklist

- [ ] **Console shows "CODAP interface initialized"**
- [ ] **Embedded using "Plugins" method (not Web View)**
- [ ] **Using latest CODAP at codap.concord.org**
- [ ] **App URL is HTTPS and publicly accessible**
- [ ] **Using Chrome or Firefox browser**
- [ ] **No security errors in console**
- [ ] **Tried with small dataset first**
- [ ] **Refreshed CODAP page**
- [ ] **Cleared browser cache**

---

## 🎯 Expected Behavior When Working

When everything works correctly:

1. **Click "Send to CODAP"**
2. **See notification:** "Sending 123 rows to CODAP as dataset: WaterQualityData"
3. **After 2-3 seconds:** "Successfully sent 123 rows to CODAP dataset: WaterQualityData"
4. **In CODAP:** New dataset appears in the left panel
5. **Console shows:** Success messages

---

## 📞 If Still Not Working

If you've tried all the above and it's still not working:

1. **Share the console output** (copy/paste the messages from F12 console)
2. **Confirm your embedding method** (Web View vs Plugin)
3. **Check your app URL** (should be HTTPS shinyapps.io URL)
4. **Try the CSV download method** as a workaround

The most common cause is using the Web View component instead of the proper Data Interactive Plugin method.

---

**Remember:** The Data Interactive Plugin API is different from just embedding a webpage in an iframe. You need to use CODAP's plugin system specifically.

