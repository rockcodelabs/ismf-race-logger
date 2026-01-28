# Touch Display UX - Raspberry Pi 7" Optimization

## Overview

This application provides a **dual-interface system** with separate layouts and styles optimized for desktop and touch displays. The touch interface is specifically designed for the **Raspberry Pi Touch Display 2** (7", 800x480 resolution).

## Key Features

### 1. **Automatic Detection**

The system automatically detects touch displays using multiple methods:

- **Media Query Detection**: CSS uses `@media (any-pointer: coarse)` to detect touchscreen input
- **User-Agent Detection**: Server-side detection of Raspberry Pi, mobile devices
- **Cookie Persistence**: User preference is saved for 1 year
- **Manual Toggle**: Users can switch between modes with `?touch=1` or `?touch=0` query parameters

### 2. **Touch-Optimized Design Standards**

Based on industry best practices:

| Element | Desktop | Touch | Specification |
|---------|---------|-------|---------------|
| **Minimum Button Size** | 40px | 48px | 9mm finger pad minimum |
| **Primary Button Size** | 40px | 56-72px | Larger for main actions |
| **Form Input Height** | 40px | 48-64px | Easy to tap and type |
| **Spacing Between Elements** | 4-8px | 8-16px | Prevent accidental taps |
| **Icon Size in Buttons** | 16-20px | 28-32px | Better visibility |
| **Font Size** | 14-16px | 18-24px | Readable at arm's length |

### 3. **Visual & Audio Feedback**

Touch interactions include:

- **Scale Animation**: Buttons scale to 96% when pressed
- **Ripple Effect**: White radial gradient animates outward on touch
- **Audio Feedback**: Optional beep sound on button press (800Hz, 100ms)
- **Tap Highlight**: Pink highlight color on touch
- **Shadow Changes**: Inset shadow on active state

### 4. **Separate View Templates**

The system uses Rails variants for different interfaces:

```
app/views/
├── home/
│   ├── index.html.erb       # Desktop view (default)
│   └── index.touch.html.erb # Touch-optimized view
├── sessions/
│   ├── new.html.erb          # Desktop sign-in
│   └── new.touch.html.erb    # Touch-optimized sign-in
└── layouts/
    ├── application.html.erb  # Desktop layout
    └── touch.html.erb        # Touch-optimized layout
```

### 5. **Touch Layout Features**

The `touch.html.erb` layout includes:

- **Larger logo**: 120x120px (vs 40-48px on desktop)
- **Simplified navigation**: Focus on primary actions only
- **No scrollbars**: Clean, app-like interface
- **Disabled text selection**: Only inputs allow text selection
- **Fixed viewport**: `user-scalable=no` for app-like experience
- **Debug overlay**: Shows screen resolution and touch detection (auto-hides after 5s)

## Architecture

### Detection Flow

```
Request → ApplicationController
           ↓
       set_variant (before_action)
           ↓
       touch_display? method
           ↓
    ┌──────┴──────┐
    │             │
Priority 1:   Priority 2:
?touch param  Cookie exists?
    │             │
    ├─ Yes → Set  ├─ Yes → Use
    │   cookie    │   cookie
    │             │
Priority 3:   Priority 4:
User-Agent    Default to
detection     desktop
    │
    └─ Raspberry Pi,
       Mobile, etc.
```

### CSS Architecture

```css
/* Base styles for all devices */
.btn { min-height: 2.5rem; }

/* Touch devices (any touchscreen) */
@media (any-pointer: coarse) {
  .btn { min-height: 3rem; } /* 48px */
}

/* Small touch displays (Raspberry Pi) */
@media (any-pointer: coarse) and (max-width: 900px) {
  .btn { min-height: 4rem; } /* 64px */
}
```

## Usage

### For Users

**Access Touch Mode:**
1. Navigate to home page on Raspberry Pi - automatically detects
2. Or manually: `https://yourapp.com/?touch=1`
3. Preference is saved in cookie for 1 year

**Switch Back to Desktop:**
- Click "Switch to Desktop Mode" link in footer
- Or use: `https://yourapp.com/?touch=0`

### For Developers

**Create Touch-Optimized View:**

```erb
<!-- app/views/your_controller/action.touch.html.erb -->
<div class="touch-spacing">
  <h1 class="text-4xl font-extrabold">Large Title</h1>
  
  <%= link_to "Action", path, class: "touch-btn touch-btn-primary" do %>
    <svg>...</svg>
    <span>Button Text</span>
  <% end %>
</div>
```

**Touch-Specific CSS Classes:**

```css
.touch-btn              /* Base touch button (80px height) */
.touch-btn-primary      /* Primary action button (gradient, shadow) */
.touch-btn-secondary    /* Secondary action button */
.touch-input            /* Large form input (70px height) */
.touch-label            /* Large form label (1.25rem) */
.touch-flash            /* Large flash message */
.touch-spacing          /* Standard padding (2rem) */
.touch-spacing-lg       /* Large padding (3rem) */
```

## Testing

### Manual Testing

1. **Desktop Browser:**
   ```
   http://localhost:3000/
   ```

2. **Touch Mode (Desktop):**
   ```
   http://localhost:3000/?touch=1
   ```

3. **Raspberry Pi:**
   - Open Chromium browser
   - Navigate to app URL
   - Should auto-detect and use touch layout

### Debug Information

When in touch mode, a debug badge appears for 5 seconds showing:
- Screen resolution
- Touch support detection
- Console logs with full device details

**Console Output:**
```
Touch Display Detected:
- Screen: 800x480
- Pixel Ratio: 1
- Touch Support: true
- User Agent: Mozilla/5.0 (X11; Linux armv7l)...
```

## Best Practices

### Touch Button Design

✅ **DO:**
- Use minimum 48x48px tap targets
- Add 8px spacing between interactive elements
- Provide visual feedback on touch (scale, ripple)
- Use large, bold fonts (1.25rem+)
- Include large icons (1.5-2rem)
- Test with actual fingers, not mouse

❌ **DON'T:**
- Create buttons smaller than 44x44px
- Place interactive elements too close together
- Rely only on hover states
- Use small fonts (under 1rem on small screens)
- Enable text selection on UI elements

### Responsive Strategy

This project uses **device capability detection** rather than just screen size:

1. **Desktop (default)**: Mouse/trackpad input, normal UI
2. **Touch (any size)**: Touchscreen input, larger tap targets
3. **Small Touch**: Raspberry Pi 7", extra-large UI elements

This ensures:
- iPads with mice get desktop UI
- Large touchscreen monitors get touch UI
- Raspberry Pi gets optimized small-screen touch UI

## Performance Considerations

- **CSS only**: All touch styles are CSS-based, no JavaScript runtime cost
- **Audio feedback**: Lazily initialized Web Audio API (only when first button is pressed)
- **No external dependencies**: Pure Tailwind CSS + vanilla JavaScript
- **Cached detection**: Cookie prevents re-detection on every request

## Browser Support

Touch features require:
- Modern browser with CSS `@media (any-pointer)` support
- Web Audio API for audio feedback (optional)
- Touch events API or Pointer events API

**Tested on:**
- ✅ Raspberry Pi OS (Chromium)
- ✅ Chrome/Edge (desktop + touch laptops)
- ✅ Safari iOS/iPadOS
- ✅ Firefox desktop

## Future Enhancements

Potential improvements:

1. **Haptic Feedback**: Use Vibration API for physical feedback
2. **Gesture Support**: Swipe gestures for navigation
3. **Voice Commands**: Voice input for hands-free operation
4. **Larger Font Option**: Additional "accessibility" mode with even larger text
5. **High Contrast Mode**: For outdoor/bright light conditions
6. **Sound Effects**: Different sounds for success/error actions

## On-Screen Keyboard

### For Raspberry Pi Kiosk (pi5cam)

The kiosk is configured to run **Squeekboard** as the on-screen keyboard for Wayland/Weston environments.

**Status**: Currently being configured. The on-screen keyboard should automatically appear when you tap on input fields.

**Manual Trigger** (if needed):
```bash
# SSH into pi5cam and start squeekboard manually
ssh rege@pi5cam.local "export WAYLAND_DISPLAY=wayland-0 && squeekboard &"
```

**Workaround for Input Fields**:

If the on-screen keyboard doesn't appear automatically:

1. **Browser-based solution** (recommended):
   - Add `autocomplete="off"` to force browser to handle input
   - Use `inputmode="text"` attribute to hint touch keyboard
   - Consider adding a "Show Keyboard" button that focuses the input

2. **HTML Input Hints**:
   ```html
   <input type="email" 
          inputmode="email" 
          autocomplete="email"
          class="touch-input" />
   
   <input type="password" 
          inputmode="text"
          autocomplete="current-password"
          class="touch-input" />
   ```

3. **JavaScript Fallback**:
   ```javascript
   // Force focus and keyboard display
   document.querySelector('input').addEventListener('touchstart', function(e) {
     this.focus();
     this.click();
   });
   ```

**Testing Keyboard**:
```bash
# Check if squeekboard is running
ssh rege@pi5cam.local "ps aux | grep squeekboard"

# View squeekboard logs
ssh rege@pi5cam.local "journalctl --user -n 50 | grep squeekboard"

# Restart kiosk service (includes keyboard)
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"
```

**Alternative Keyboards**:
- **Squeekboard**: Default, designed for Wayland (current)
- **Lomiri Keyboard**: Alternative option if squeekboard doesn't work
- **Browser fallback**: Some browsers have built-in touch keyboards

**Known Issues**:
- Squeekboard may need manual focus trigger on first use
- Some input fields may require double-tap to activate keyboard
- Keyboard visibility can be toggled with swipe gestures

**See Also**: `AGENTS.md` (@kiosk section) for remote control and debugging

---

## References

- [Web.dev - Accessible Tap Targets](https://web.dev/accessible-tap-targets/)
- [Tailwind CSS - Responsive Design](https://tailwindcss.com/docs/responsive-design)
- [MDN - Pointer Events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events)
- [Material Design - Touch Targets](https://m3.material.io/foundations/interaction/space-between-components)
- [Squeekboard Documentation](https://gitlab.gnome.org/World/Phosh/squeekboard)