# Touch Screen Implementation - Testing Checklist

**Version:** 2.0  
**Date:** 2025-01-29  
**Purpose:** Manual testing verification for touch screen implementation

---

## Overview

This checklist ensures all touch screen features work correctly on both development (Mac with Docker) and production (Raspberry Pi with 7" touch display).

**Test Environments:**
1. **Mac (Development)** - Docker, `http://localhost:3000?touch=1`
2. **Raspberry Pi (Production)** - Touch Display 2 (800×480), Kiosk mode

---

## Pre-Test Setup

### Mac (Development)

```bash
# 1. Start Docker containers
docker compose up -d

# 2. Check logs
docker compose logs -f app

# 3. Verify server is running
curl http://localhost:3005

# 4. Open browser
open http://localhost:3005?touch=1
```

### Raspberry Pi (Production)

```bash
# 1. SSH to Pi
ssh pi@pi5main.local

# 2. Check kiosk service status
sudo systemctl status chromium-kiosk

# 3. Check Chromium logs
journalctl -u chromium-kiosk -f

# 4. Verify network connectivity
ping pi5main.local
```

---

## Test Categories

### ✅ = Pass | ❌ = Fail | ⚠️ = Issue (Note Below)

---

## 1. Touch Mode Detection & Activation

### Mac (Development)

| Test | Expected Result | Mac Status | Notes |
|------|----------------|------------|-------|
| Visit `?touch=1` | Touch layout loads | ☐ | |
| Body has `touch-mode` class | CSS class present | ☐ | |
| Cookie `touch_display=1` set | Check DevTools → Application → Cookies | ☐ | |
| Navigate to login (no param) | Touch mode persists | ☐ | |
| Visit `?touch=0` | Desktop layout returns | ☐ | |
| Cookie `touch_display=0` set | Desktop mode persists | ☐ | |

### Raspberry Pi (Production)

| Test | Expected Result | Pi Status | Notes |
|------|----------------|-----------|-------|
| Open kiosk (first time) | Auto-detects 800×480, reloads | ☐ | |
| Cookie `touch_display=1` set | Persists after reboot | ☐ | |
| Reboot Pi | Touch mode still active | ☐ | |

---

## 2. Page Layout & Styling

### Mac (Development)

| Test | Expected Result | Mac Status | Notes |
|------|----------------|------------|-------|
| `touch.css` loaded | Check Network tab for `touch.css` | ☐ | |
| Large buttons visible | Min 80px height, readable text | ☐ | |
| Touch logo displays | 120×120px, red gradient | ☐ | |
| Proper spacing | No overlapping elements | ☐ | |
| Flash messages styled | Green (notice), Red (alert) | ☐ | |

### Raspberry Pi (Production)

| Test | Expected Result | Pi Status | Notes |
|------|----------------|-----------|-------|
| All content fits screen | No horizontal scroll | ☐ | |
| Buttons easy to press | Touch targets ≥56px | ☐ | |
| Text readable | Font size appropriate | ☐ | |
| Colors visible | Good contrast on display | ☐ | |

---

## 3. Home Page (Touch Mode)

### Not Authenticated

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| ISMF logo displays | 120×120px, centered | ☐ | ☐ | |
| "Sign In" button visible | Large, red gradient, 120px height | ☐ | ☐ | |
| Footer displays | ISMF © 2025, bottom of page | ☐ | ☐ | |
| NO navigation bar | Nav only on sub-pages | ☐ | ☐ | |
| Click "Sign In" | Navigates to login page | ☐ | ☐ | |

### Authenticated (Admin)

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| "Admin Dashboard" button | Links to `/admin` | ☐ | ☐ | |
| "Sign Out" button | Destroys session | ☐ | ☐ | |
| Click "Sign Out" | Returns to home (not authenticated) | ☐ | ☐ | |

---

## 4. Login Page (Touch Mode)

### Layout

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Page title "Sign In" in nav | Displays in navbar | ☐ | ☐ | |
| Navigation bar visible | Home, Back, Hamburger buttons | ☐ | ☐ | |
| Touch logo displays | Above form | ☐ | ☐ | |
| Email input large | 70px height, clear placeholder | ☐ | ☐ | |
| Password input large | 70px height, masked | ☐ | ☐ | |
| Labels readable | 1.25rem font, bold | ☐ | ☐ | |
| "Sign In" button | Primary style, 80px height | ☐ | ☐ | |
| "Back to Home" button | Secondary style | ☐ | ☐ | |

### Navigation Buttons

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Click "Hamburger" | Nav toggles (animation) | ☐ | ☐ | |
| Click "Home" | Returns to home page | ☐ | ☐ | |
| Click "Back" | Goes back in history | ☐ | ☐ | |
| Scroll down 100px+ | Nav auto-hides (slides up) | ☐ | ☐ | |
| Scroll up | Nav auto-shows (slides down) | ☐ | ☐ | |

---

## 5. Virtual Keyboard

### Mac (Development)

| Test | Expected Result | Mac Status | Notes |
|------|----------------|------------|-------|
| `simple-keyboard` loaded | Check Network tab, 200 OK | ☐ | |
| Keyboard controller connected | Console: "🎹 Keyboard controller connected" | ☐ | ☐ | |
| Touch email input | Keyboard appears at bottom | ☐ | |
| Keyboard doesn't overlap input | Input scrolls into view | ☐ | |
| **Preview display visible** | Left of spacebar, "Type here..." | ☐ | |
| Type characters | Preview updates with text | ☐ | |
| Type in password field | Preview shows bullets (`•••`) | ☐ | |
| Click shift | Layout changes to uppercase | ☐ | |
| Click shift again | Returns to lowercase | ☐ | |
| Click backspace | Deletes last character | ☐ | |
| Click enter | Submits form | ☐ | |
| Audio feedback | Beep sound on key press | ☐ | |
| Click outside input | Keyboard hides | ☐ | |

### Raspberry Pi (Production)

| Test | Expected Result | Pi Status | Notes |
|------|----------------|-----------|-------|
| Touch email input | **ONLY custom keyboard appears** | ☐ | |
| **NO native keyboard** | Chromium keyboard disabled | ☐ | |
| **Preview display visible** | Shows typed text | ☐ | |
| **Preview for passwords** | Shows bullets, not text | ☐ | |
| Touch keyboard buttons | Characters appear in input | ☐ | |
| Visual feedback | Button presses animate | ☐ | |
| Audio feedback | Beep on key press | ☐ | |
| Shift key works | Toggles case | ☐ | |
| Backspace works | Deletes characters | ☐ | |
| Enter submits form | Form submission works | ☐ | |
| Number keys work | 0-9 input correctly | ☐ | |
| Special chars work | @ . _ symbols | ☐ | |
| Spacebar works | Adds space | ☐ | |
| Touch "Hide" (if exists) | Keyboard dismisses | ☐ | |

---

## 6. Form Submission

### Mac & Pi

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Enter valid email | Input accepts text | ☐ | ☐ | |
| Enter valid password | Input masked, accepts text | ☐ | ☐ | |
| Click "Sign In" | Form submits | ☐ | ☐ | |
| **Login with keyboard Enter** | Form submits via keyboard | ☐ | ☐ | |
| Invalid credentials | Shows error flash message | ☐ | ☐ | |
| Valid credentials | Redirects to dashboard/home | ☐ | ☐ | |

---

## 7. Console Logging & Debugging

### Mac (Docker Logs)

| Test | Expected Result | Status | Notes |
|------|----------------|--------|-------|
| Check Docker logs | `docker compose logs -f app` | ☐ | |
| See Rails logs | Touch detection logs visible | ☐ | |
| JavaScript console | Browser DevTools → Console | ☐ | |
| Stimulus controllers log | "🎹 Keyboard controller connected" | ☐ | |
| "📱 Touch detection controller connected" | On page load | ☐ | |
| "🧭 Touch navigation controller connected" | On pages with nav | ☐ | |
| Keyboard events log | "🔑 Key pressed: q" | ☐ | |
| "⌨️ Keyboard shown for: email_address" | On focus | ☐ | |
| "🚫 Keyboard hidden" | On blur | ☐ | |
| No JavaScript errors | Console clean | ☐ | |

### Raspberry Pi (Remote Logs)

| Test | Expected Result | Status | Notes |
|------|----------------|--------|-------|
| SSH to Pi | `ssh pi@pi5main.local` | ☐ | |
| Check Chromium logs | `journalctl -u chromium-kiosk -f` | ☐ | |
| See console logs | JavaScript logs visible | ☐ | |
| Verify Chromium flags | `ps aux | grep chromium` | ☐ | |
| `--disable-touch-keyboard` present | Native keyboard disabled | ☐ | |
| `--disable-features=VirtualKeyboard` present | Extra keyboard prevention | ☐ | |

---

## 8. Cookie & Session Persistence

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Set touch mode | Cookie persists 1 year | ☐ | ☐ | |
| Close browser | Cookie remains | ☐ | ☐ | |
| Reopen browser | Touch mode still active | ☐ | ☐ | |
| Clear cookies | Touch mode resets | ☐ | ☐ | |
| Pi reboot | Touch mode persists | N/A | ☐ | |

---

## 9. Performance & Responsiveness

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Page load time | <2 seconds | ☐ | ☐ | |
| Keyboard appears quickly | <500ms after focus | ☐ | ☐ | |
| No lag on key press | Immediate feedback | ☐ | ☐ | |
| Smooth animations | 60fps nav hide/show | ☐ | ☐ | |
| No memory leaks | Check DevTools → Performance | ☐ | ☐ | |

---

## 10. Edge Cases & Error Handling

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Disconnect network | Offline behavior graceful | ☐ | ☐ | |
| Rapid key presses | No duplicate input | ☐ | ☐ | |
| Focus multiple inputs quickly | Keyboard switches correctly | ☐ | ☐ | |
| Long text input | Preview truncates/scrolls | ☐ | ☐ | |
| Special characters | All render correctly | ☐ | ☐ | |
| Empty form submission | Validation works | ☐ | ☐ | |

---

## 11. Accessibility

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| ARIA labels present | Nav buttons have labels | ☐ | ☐ | |
| Form labels associated | `for` attribute matches IDs | ☐ | ☐ | |
| Button titles present | Hover shows tooltips | ☐ | N/A | |
| Color contrast | Readable on Pi display | N/A | ☐ | |

---

## 12. Regression Testing

| Test | Expected Result | Mac | Pi | Notes |
|------|----------------|-----|-----|-------|
| Desktop mode still works | Visit without `?touch=1` | ☐ | N/A | |
| Desktop nav works | Standard navigation intact | ☐ | N/A | |
| Mobile responsive works | Test on phone browser | ☐ | N/A | |
| Admin pages work | No touch mode conflicts | ☐ | ☐ | |

---

## Test Results Summary

### Mac (Development)

- **Total Tests:** ___
- **Passed:** ___
- **Failed:** ___
- **Issues:** ___

### Raspberry Pi (Production)

- **Total Tests:** ___
- **Passed:** ___
- **Failed:** ___
- **Issues:** ___

---

## Issues & Notes

### Mac Issues

1. **Issue #1:**
   - Description:
   - Steps to reproduce:
   - Severity: (Critical/High/Medium/Low)
   - Status: (Open/In Progress/Resolved)

### Pi Issues

1. **Issue #1:**
   - Description:
   - Steps to reproduce:
   - Severity:
   - Status:

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| **Developer** | | | |
| **QA Tester** | | | |
| **Product Owner** | | | |

---

## Quick Commands Reference

### Mac Testing

```bash
# Start app
docker compose up -d

# View logs
docker compose logs -f app

# Open in browser
open http://localhost:3005?touch=1

# Check assets
curl http://localhost:3005/assets/touch.css

# Rails console
docker compose exec app bin/rails console
```

### Pi Testing

```bash
# SSH to Pi
ssh pi@pi5main.local

# Restart kiosk
sudo systemctl restart chromium-kiosk

# View logs
journalctl -u chromium-kiosk -f

# Check Chromium process
ps aux | grep chromium

# Clear browser cache
rm -rf ~/.config/chromium/Default/Cache/*

# Reboot Pi
sudo reboot
```

---

## Next Steps After Testing

1. ✅ Document all issues found
2. ✅ Fix critical issues
3. ✅ Retest failed items
4. ✅ Update documentation if needed
5. ✅ Deploy to production (if not already)
6. ✅ Monitor production logs for 24 hours
7. ✅ Gather user feedback
8. ✅ Plan future enhancements

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-29  
**Maintained By:** Development Team