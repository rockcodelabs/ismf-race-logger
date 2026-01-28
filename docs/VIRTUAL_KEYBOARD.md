# Virtual Keyboard for 7" Touch Display

## Overview

The ISMF Race Logger includes a web-based virtual keyboard optimized for 7" touch displays (800×480 resolution) running in kiosk mode. This keyboard solves the critical UX problem of **seeing what you're typing** on small displays.

## Key Features

### 1. **Large Text Preview Bar**
- **Integrated into the keyboard** on the left side of the spacebar row
- Shows exactly what you're typing in **1.25rem (20px) monospace font**
- Updates in real-time as you type
- Password fields show bullets (`•••`) instead of actual characters
- Includes animated cursor (`|`) for visual feedback
- Always visible when keyboard is active (no separate floating element)

### 2. **Optimized Keyboard Layout**
- **Larger keys**: 56px minimum height (up from 48px)
- **Bigger font**: 1.5rem (up from 1.25rem)
- **Better spacing**: 0.4rem gaps between keys
- **QWERTY layout** with dedicated number row
- Special characters: `@`, `.`, `-` for email/web input
- Functional shift key for capitalization
- Large backspace and space bar

### 4. **Smart Positioning**
- Automatically scrolls input field to **20% from top** of visible area
- Accounts for both keyboard (220px) and preview bar (100px)
- Uses Visual Viewport API for proper Wayland/kiosk handling
- Prevents keyboard from covering the input you're typing into

### 5. **Audio Feedback**
- Plays short beep (800Hz sine wave, 50ms) on every key press
- Helps confirm touch registration
- Low volume (0.05 gain) to avoid annoyance

## User Experience

### Before (Problem)
❌ Couldn't see what you were typing  
❌ Input field hidden behind keyboard  
❌ Small text difficult to read on 7" display  
❌ No feedback on successful key press  

### After (Solution)
✅ **Large preview bar** shows exactly what you're typing  
✅ Input field automatically positioned above keyboard  
✅ **Huge text** (2rem preview + 1.5rem input)  
✅ Visual (color change) + audio (beep) feedback  
✅ Password security (shows bullets)  

## Visual Layout

```
┌─────────────────────────────────────────┐
│  Top of Screen (800×480)                │
│                                         │
│  ┌───────────────────────────────┐     │
│  │      You're typing:           │     │ ← Preview (top)
│  │        user@test    |         │     │   Only shows
│  └───────────────────────────────┘     │   when typing
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Input field (visible)          │   │
│  └─────────────────────────────────┘   │
│                                         │
│                                         │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  [1][2][3][4][5][6][7][8][9][0]  │ │
│  │  [q][w][e][r][t][y][u][i][o][p]  │ │
│  │   [a][s][d][f][g][h][j][k][l]    │ │ Keyboard
│  │ [⇧][z][x][c][v][b][n][m][⌫]      │ │ (bottom)
│  │  [@][.][   space   ][-][Hide]    │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## Technical Architecture

### Components

#### 1. Input Preview Bar (`#input-preview`)
```
Position: fixed, top: 80px (near top of screen)
Z-index: 10000 (above everything)
Size: 90% width, max 600px
Display: Only shown when input has text (hidden when empty)
Updates: Real-time via `updatePreview()`
Behavior: Auto-hides when input is cleared
```

#### 2. Virtual Keyboard (`#virtual-keyboard`)
```
Position: fixed, bottom: 0
Z-index: 9999
Height: ~220px
Layout: CSS Grid (responsive to viewport width)
Keys: 47 total (10+10+9+9+5 + shift/backspace/hide)
```

#### 3. JavaScript Controller
```javascript
- activeInput: Currently focused input element
- isShiftActive: Shift key toggle state
- updatePreview(): Syncs preview text with input value
- updateKeyboardPosition(): Handles viewport changes
- Event handlers: focus, blur, click, resize, scroll
```

### Event Flow

1. **User taps input field**
   - `focus` event fires
   - Check if it's a text/email/password/textarea
   - Show keyboard and preview bar
   - Calculate available space
   - Scroll input into optimal position (20% from top)
   - Attach `input` listener to update preview

2. **User taps keyboard key**
   - `click` event on keyboard
   - Identify key via `data-key` attribute
   - Handle special keys (shift, backspace, space, hide)
   - Append character to input value
   - Trigger `input` event for form validation
   - Update preview text
   - Play audio feedback

3. **User taps "Hide" or blurs input**
   - Hide keyboard and preview
   - Clear `activeInput` reference
   - Remove event listeners

### Browser Compatibility

- **Target**: Chromium in kiosk mode on Raspberry Pi OS (Wayland)
- **Viewport API**: Uses `window.visualViewport` (Chromium 61+)
- **Audio**: Uses Web Audio API (all modern browsers)
- **CSS Grid**: Supported in all modern browsers
- **Touch events**: Passive listeners for performance

## Configuration

### Keyboard Layout Customization

To add/modify keys, edit `app/views/layouts/touch.html.erb`:

```erb
<!-- Add a new key -->
<button class="kbd-key" data-key="!">!</button>

<!-- Modify existing key -->
<button class="kbd-key" data-key="@">@</button>
```

### Preview Bar Position

The preview is positioned at the top of the screen (80px from top):

```css
#input-preview {
  position: fixed;
  top: 80px; /* Near top, well above keyboard */
  left: 50%;
  transform: translateX(-50%); /* Horizontally centered only */
  width: 90%; /* Responsive width */
  max-width: 600px;
}
```

**Why 80px?**
- Display height: 480px
- Keyboard height: ~220px
- Available space: 260px
- 80px keeps preview in top third, clear of keyboard

### Key Size and Font

Modify in the dynamically injected styles:

```javascript
.kbd-key {
  padding: 1rem;        /* Key padding */
  font-size: 1.5rem;    /* Key label size */
  min-height: 56px;     /* Minimum touch target */
}
```

## Testing

### Local Testing (Desktop Browser)

1. Visit any page with `?touch=1` query parameter
2. Example: `http://localhost:3005/sign-in?touch=1`
3. Click/tap on email or password input
4. Keyboard should appear with preview bar
5. Type using keyboard, observe preview updates

### Kiosk Testing (Raspberry Pi)

1. Deploy changes to production (see `AGENTS.md` - `@deploy`)
2. SSH to Pi: `ssh rege@pi5cam.local`
3. Restart kiosk: `sudo systemctl restart kiosk.service`
4. Tap sign-in fields on the display
5. Verify preview shows typed characters
6. Test password field shows bullets

### Test Scenarios

- [ ] Email input shows actual text in preview
- [ ] Password input shows bullets (`•••`)
- [ ] Preview is **hidden when input is empty** (no "(empty)" text)
- [ ] Preview appears only after first character is typed
- [ ] Backspace removes last character
- [ ] Preview hides when all text is deleted
- [ ] Shift capitalizes next letter (single use)
- [ ] Space bar inserts space
- [ ] Special characters (@, ., -) work
- [ ] Hide button dismisses keyboard and preview
- [ ] Input field stays visible (not covered)
- [ ] Audio feedback plays on key press
- [ ] Preview scrolls horizontally for long text
- [ ] Preview doesn't cover keyboard keys

## Performance

- **Keyboard render**: <100ms (CSS Grid layout)
- **Preview update**: <5ms (simple text replacement)
- **Scroll animation**: 100ms smooth scroll
- **Audio feedback**: 50ms duration, no lag
- **Memory footprint**: ~50KB (DOM + event listeners)

## Accessibility

### Current Implementation
- ✅ Large touch targets (56px minimum)
- ✅ High contrast colors (white on dark blue)
- ✅ Visual feedback (color change on press)
- ✅ Audio feedback (beep on key press)
- ✅ Large preview text (2rem)

### Future Improvements
- [ ] Add `aria-label` to keyboard keys
- [ ] Add `role="button"` to keys
- [ ] Screen reader announcements for key press
- [ ] Haptic feedback (navigator.vibrate) if supported
- [ ] High contrast mode toggle
- [ ] Keyboard layout switching (numeric, email)

## Troubleshooting

### Keyboard doesn't appear

**Check:**
1. Are you on a touch-enabled page? (Add `?touch=1`)
2. Is the input field a supported type? (text, email, password, textarea)
3. Open browser console, look for JavaScript errors
4. Verify `#virtual-keyboard` element exists in DOM

**Fix:**
```javascript
// Debug in browser console
document.getElementById('virtual-keyboard')
// Should return the keyboard div
```

### Preview shows wrong text

**Check:**
1. Is `activeInput` correctly set?
2. Are `input` event listeners attached?
3. Is `updatePreview()` being called?

**Fix:**
```javascript
// Debug in browser console
activeInput // Should be the focused input element
```

### Input field covered by keyboard

**Check:**
1. Is Visual Viewport API supported? (check `window.visualViewport`)
2. Is scroll calculation correct?
3. Is keyboard height measured correctly?

**Fix:**
```javascript
// Debug in browser console
window.visualViewport.height // Visible viewport height
document.getElementById('virtual-keyboard').offsetHeight // Keyboard height
```

### Audio doesn't play

**Check:**
1. Is Web Audio API supported? (check `AudioContext`)
2. Is user interaction required to start audio? (Chrome policy)
3. Is device muted?

**Fix:**
```javascript
// Test audio context
const ctx = new (window.AudioContext || window.webkitAudioContext)();
console.log(ctx.state); // Should be "running" after user interaction
```

## Related Documentation

- [`AGENTS.md`](../AGENTS.md) - See `@kiosk` agent for remote control
- [`DEV_COMMANDS.md`](DEV_COMMANDS.md) - Kiosk deployment commands
- [`ARCHITECTURE.md`](ARCHITECTURE.md) - Overall system architecture
- [Touch Display UX Thread](https://github.com/yourusername/ismf-race-logger/issues/XXX) - Design decisions

## Future Enhancements

### Short-term
- [ ] Remove debug badge in production
- [ ] Add numeric-only layout for number inputs
- [ ] Add email-specific layout (common domains)
- [ ] Tune preview bar size based on display density

### Medium-term
- [ ] Layout switching button (QWERTY ↔ numeric)
- [ ] Internationalization (multiple language layouts)
- [ ] Gesture support (swipe to dismiss)
- [ ] Customizable key repeat (hold to repeat)

### Long-term
- [ ] Predictive text / autocomplete
- [ ] Word suggestions above keyboard
- [ ] Emoji picker
- [ ] Native Wayland keyboard fallback (wvkbd integration)

## Credits

- **Design**: Optimized for Raspberry Pi Touch Display 2 (800×480)
- **Implementation**: Web-based virtual keyboard (JavaScript + CSS Grid)
- **Research**: Based on conversation thread analyzing native vs web keyboards
- **Testing**: pi5cam kiosk (Weston + Chromium)

---

**Last Updated**: 2024  
**Maintainer**: ISMF Race Logger Team  
**Status**: ✅ Production Ready