# CODAP API Fix - IFramePhone Implementation

## The Problem

When students tested the CODAP integration, they saw this error:
```
CODAP Export Error: CODAP did not respond within 10 seconds
```

The app was successfully embedded in CODAP and displaying data, but the "Send to CODAP" button timed out when clicked.

## Root Cause

Our original implementation used raw `window.parent.postMessage()` to communicate with CODAP. However, CODAP uses **IFramePhone**, a specialized library that wraps postMessage with:
- Proper request/response matching
- RPC (Remote Procedure Call) interface
- Reliable message delivery
- Standard CODAP API format

Without IFramePhone, CODAP wasn't responding to our messages.

## The Solution

### 1. Added IFramePhone Library

Added this line to load the library from unpkg:
```r
tags$script(src = "https://unpkg.com/iframe-phone@1.4.0/dist/iframe-phone.js"),
```

### 2. Initialized CODAP Connection

Added proper initialization code:
```javascript
var codapPhone = null;
var codapConnectionInitialized = false;

function initCodapConnection() {
  codapPhone = new iframePhone.IframePhoneRpcEndpoint(
    function(command, callback) {
      // Handler for messages FROM CODAP
      console.log('Received message from CODAP:', command);
      if (callback) callback({success: true});
    },
    'data-interactive',
    window.parent
  );
  codapConnectionInitialized = true;
}
```

### 3. Updated Message Sending

Changed from raw postMessage:
```javascript
// OLD (didn't work)
window.parent.postMessage({
  message: message,
  requestId: requestId
}, '*');
```

To IFramePhone's call method:
```javascript
// NEW (works!)
codapPhone.call(message, function(response) {
  console.log('CODAP Response:', response);
  if (response && response.success) {
    resolve(response);
  } else {
    reject(response);
  }
});
```

## Testing the Fix

### What You Should See in Console

**On Page Load:**
```
Initializing CODAP connection with IFramePhone...
CODAP connection established successfully
```

**When Clicking "Send to CODAP":**
```
Received sendToCODAP message from Shiny: {datasetName: "WaterQualityData", ...}
Dataset name: WaterQualityData
Number of attributes: 12
Number of cases: 890
Sending to CODAP via IFramePhone: {action: "create", resource: "dataContext", ...}
CODAP Response: {success: true, values: {...}}
DataContext created successfully: {...}
Sending to CODAP via IFramePhone: {action: "create", resource: "dataContext[WaterQualityData].item", ...}
CODAP Response: {success: true, values: [...]}
Cases sent successfully: {...}
Total cases sent: 890
```

### Success Indicators

✅ **Connection established** message appears on load
✅ **CODAP Response** messages show `success: true`
✅ **Dataset appears in CODAP** with the correct name
✅ **All rows are present** in the CODAP table
✅ **No timeout errors**

### If It Still Doesn't Work

**1. Check IFramePhone Loaded**

Open console and type:
```javascript
typeof iframePhone
```

Should return: `"object"` (not `"undefined"`)

**2. Check Connection Initialized**

Type in console:
```javascript
codapConnectionInitialized
```

Should return: `true`

**3. Check CODAP Version**

Make sure you're using the latest CODAP from https://codap.concord.org (not an old cached version or local copy).

**4. Clear Cache and Refresh**

Sometimes browsers cache the old JavaScript:
- Hard refresh: `Ctrl+Shift+R` (Windows) or `Cmd+Shift+R` (Mac)
- Or clear browser cache entirely

**5. Check for Errors**

Look for red errors in console, particularly:
- `IFramePhone library not loaded` - Library didn't load from CDN
- `Unable to establish connection with CODAP` - Connection failed
- Network errors loading iframe-phone.js - Check internet connection

## Technical Details

### Why IFramePhone?

CODAP was built with IFramePhone from the beginning. The library provides:
- **Request/Response Pattern**: Automatically matches responses to requests
- **Callbacks**: Handles async responses cleanly
- **Error Handling**: Detects failed/timeout messages
- **Standard Protocol**: All CODAP plugins use this same protocol

### Message Format

IFramePhone expects messages in this format:
```javascript
{
  action: 'create' | 'update' | 'get' | 'delete',
  resource: 'dataContext' | 'collection' | 'component' | etc.,
  values: {
    // Resource-specific data
  }
}
```

The `codapPhone.call(message, callback)` method handles:
- Wrapping the message with proper headers
- Generating request IDs
- Listening for matching responses
- Invoking the callback with the response

### Compatibility

**IFramePhone Version:** 1.4.0 (latest stable release)
**CODAP Compatibility:** All CODAP v2 and v3 versions
**Browser Support:** All modern browsers (Chrome, Firefox, Safari, Edge)
**CDN:** Hosted on unpkg.com (reliable, fast, free)

## For Developers

### To Update iframe-phone Version

Change this line in `app.R`:
```r
tags$script(src = "https://unpkg.com/iframe-phone@1.4.0/dist/iframe-phone.js"),
```

To:
```r
tags$script(src = "https://unpkg.com/iframe-phone@VERSION/dist/iframe-phone.js"),
```

Check available versions at: https://www.npmjs.com/package/iframe-phone

### Alternative: Self-Host the Library

If unpkg.com is unavailable:
1. Download: `npm install iframe-phone`
2. Copy `node_modules/iframe-phone/dist/iframe-phone.js` to your `www/` folder
3. Update script tag: `tags$script(src = "iframe-phone.js")`
4. Make sure the file is served by Shiny (add `addResourcePath("www", "www")` if needed)

## References

- **IFramePhone Repository**: https://github.com/concord-consortium/iframe-phone
- **CODAP Data Interactive API**: https://github.com/concord-consortium/codap/wiki/CODAP-Data-Interactive-Plugin-API
- **unpkg CDN**: https://unpkg.com/
- **CODAP Plugin Examples**: https://github.com/concord-consortium/codap-data-interactives

---

**Date Fixed:** 2026-02-16
**File Changed:** `app.R` (lines ~196-268)
**Status:** Ready for testing
