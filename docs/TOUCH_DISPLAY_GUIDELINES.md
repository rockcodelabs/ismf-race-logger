# Touch Display Guidelines

## Overview

The ISMF Race Logger includes a kiosk mode optimized for **7" touch displays** (Raspberry Pi Touch Display 2, 800×480 resolution). This document defines requirements for creating and maintaining touch-optimized views.

---

## Hardware & Environment

- **Display**: Raspberry Pi Touch Display 2
- **Resolution**: 800×480 pixels
- **Compositor**: Weston (Wayland)
- **Browser**: Chromium in kiosk mode
- **Device**: pi5cam.local (Raspberry Pi 5)

---

## Navigation Hierarchy

Touch views follow a clear navigation hierarchy with back buttons on every page (except root):

```
Home (root)
├── Sign In ──────────────────> [Back to Home]
│   └── Dashboard (authenticated) ──> [Back to Home] [Sign Out]
│       ├── Users List ──────────> [Back to Dashboard] [Sign Out]
│       │   ├── View User ──────> [Back to Users List] [Sign Out]
│       │   ├── Edit User ──────> [Back to Users List] [Sign Out]
│       │   └── New User ───────> [Back to Users List] [Sign Out]
│       └── (other admin pages) ──> [Back to Dashboard] [Sign Out]
```

### Navigation Rules

1. **Root page** (home) has NO back button
2. **Sign In** page → back to Home
3. **Dashboard** → back to Home (allows switching accounts)
4. **Admin pages** → back to Dashboard
5. **Detail pages** → back to List
6. **All authenticated pages** → Sign Out button (top-right)

---

## Touch View Requirements (MANDATORY)

### Navigation Elements

Every touch view **MUST** include:

#### 1. Back Button (Required on all non-root pages)
```erb
<%= link_to root_path, class: "touch-btn-icon" do %>
  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2.5rem; height: 2.5rem;">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
  </svg>
<% end %>
```

- **Position**: Top-left corner
- **Size**: 64×64px
- **Style**: `touch-btn-icon` class
- **Icon**: Left arrow
- **Destination**: Previous logical page (home, dashboard, etc.)

#### 2. Sign Out Button (Required on authenticated pages)
```erb
<%= button_to session_path, method: :delete, class: "touch-btn-icon" do %>
  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2.5rem; height: 2.5rem;">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
  </svg>
<% end %>
```

- **Position**: Top-right corner
- **Size**: 64×64px
- **Style**: `touch-btn-icon` class
- **Icon**: Sign out arrow

### 3. Desktop Mode Toggle (Required on all pages)
```erb
<%= link_to "Switch to Desktop Mode", current_path(touch: 0), class: "text-white/50 text-lg hover:text-white/70" %>
```

- **Position**: Footer (bottom center)
- **Text**: "Switch to Desktop Mode"
- **Link**: Current page with `?touch=0`

### Back Button Destinations by Page

| Current Page | Back Button Destination |
|--------------|------------------------|
| Home | (none - root page) |
| Sign In | `root_path` |
| Dashboard | `root_path` |
| Users List | `admin_root_path` |
| View User | `admin_users_path` |
| Edit User | `admin_users_path` |
| New User | `admin_users_path` |

---

## File Naming Convention

Touch views use the `.touch.html.erb` suffix:

```
app/views/
├── home/
│   ├── index.html.erb          # Desktop view
│   └── index.touch.html.erb    # Touch view
├── sessions/
│   ├── new.html.erb
│   └── new.touch.html.erb
└── admin/
    └── dashboard/
        ├── index.html.erb
        └── index.touch.html.erb
```

Rails automatically selects `.touch` variant when `request.variant = :touch` is set.

---

## Touch CSS Classes

### Button Classes

| Class | Purpose | Size | Color |
|-------|---------|------|-------|
| `touch-btn` | Base button style | 80px height | — |
| `touch-btn-primary` | Primary actions | 80px height | Red gradient |
| `touch-btn-secondary` | Secondary actions | 80px height | Blue gradient |
| `touch-btn-icon` | Icon-only button | 64×64px | Transparent white |

### Input Classes

| Class | Purpose | Size |
|-------|---------|------|
| `touch-input` | Form input field | 70px height, 1.25rem font |
| `touch-label` | Form label | 1.25rem font, bold |

### Layout Classes

| Class | Purpose | Padding |
|-------|---------|---------|
| `touch-spacing` | Page padding | 2rem all sides |
| `touch-spacing-lg` | Large padding | 3rem all sides |
| `touch-logo` | Logo container | 120×120px |

---

## Standard Page Layouts

### Home Page (Root)
```erb
<div class="min-h-screen flex flex-col items-center justify-center touch-spacing">
  <!-- Logo -->
  <div class="touch-logo mb-8">
    <svg><!-- logo icon --></svg>
  </div>
  
  <!-- Title -->
  <h1 class="text-5xl font-extrabold text-white mb-3 text-center">ISMF</h1>
  <h2 class="text-3xl font-bold text-ismf-red mb-8 text-center">Race Logger</h2>
  
  <!-- Actions -->
  <div class="w-full max-w-2xl flex flex-col gap-6 px-4">
    <%= link_to "Sign In", new_session_path, class: "touch-btn touch-btn-primary" do %>
      <svg><!-- icon --></svg>
      <span>Sign In</span>
    <% end %>
  </div>
  
  <!-- Footer -->
  <div class="absolute bottom-4 left-0 right-0">
    <p class="text-center text-white/40 text-base font-medium">ISMF © <%= Date.current.year %></p>
    <%= link_to "Switch to Desktop Mode", root_path(touch: 0), class: "block text-center text-white/30 text-sm mt-2" %>
  </div>
</div>
```

### Sign In Page
```erb
<div class="min-h-screen flex flex-col items-center justify-center touch-spacing">
  <!-- Logo -->
  <div class="touch-logo mb-6">
    <svg><!-- logo --></svg>
  </div>
  
  <!-- Title -->
  <div class="text-center mb-8">
    <h1 class="text-4xl font-extrabold text-white mb-2">ISMF Race Logger</h1>
    <p class="text-xl text-white/70 font-semibold">Touch to Sign In</p>
  </div>

  <!-- Form Card -->
  <div class="w-full max-w-2xl bg-white rounded-3xl shadow-2xl touch-spacing-lg">
    <%= form_with url: session_url, class: "space-y-8" do |form| %>
      <div>
        <label for="email_address" class="touch-label">Email</label>
        <%= form.email_field :email_address, class: "touch-input" %>
      </div>

      <div>
        <label for="password" class="touch-label">Password</label>
        <%= form.password_field :password, class: "touch-input" %>
      </div>

      <div class="flex flex-col gap-4">
        <%= form.submit "Sign In", class: "touch-btn touch-btn-primary cursor-pointer" %>
        
        <%= link_to root_path, class: "touch-btn touch-btn-secondary" do %>
          <svg><!-- back arrow --></svg>
          <span>Back</span>
        <% end %>
      </div>
    <% end %>
  </div>
  
  <!-- Footer -->
  <div class="mt-6">
    <p class="text-center text-white/40 text-lg font-medium">ISMF © <%= Date.current.year %></p>
  </div>
</div>
```

### Admin/Dashboard Page
```erb
<div class="min-h-screen touch-spacing">
  <!-- Header with Navigation -->
  <div class="flex items-center justify-between mb-8">
    <%= link_to root_path, class: "touch-btn-icon" do %>
      <svg><!-- back arrow --></svg>
    <% end %>
    
    <h1 class="text-4xl font-extrabold text-white">Dashboard</h1>
    
    <%= button_to session_path, method: :delete, class: "touch-btn-icon" do %>
      <svg><!-- sign out icon --></svg>
    <% end %>
  </div>

  <!-- Content -->
  <div class="space-y-6">
    <!-- Your content here -->
  </div>

  <!-- Footer -->
  <div class="mt-8 text-center">
    <%= link_to "Switch to Desktop Mode", admin_root_path(touch: 0), class: "text-white/50 text-lg" %>
  </div>
</div>
```

### Admin Sub-Pages (Users List, etc.)
```erb
<div class="min-h-screen touch-spacing">
  <!-- Header with Navigation -->
  <div class="flex items-center justify-between mb-8">
    <%= link_to admin_root_path, class: "touch-btn-icon" do %>
      <svg><!-- back arrow to dashboard --></svg>
    <% end %>
    
    <h1 class="text-4xl font-extrabold text-white">Users</h1>
    
    <%= button_to session_path, method: :delete, class: "touch-btn-icon" do %>
      <svg><!-- sign out icon --></svg>
    <% end %>
  </div>

  <!-- Content -->
  <div class="space-y-6">
    <!-- Your content here -->
  </div>

  <!-- Footer -->
  <div class="mt-8 text-center">
    <%= link_to "Switch to Desktop Mode", admin_users_path(touch: 0), class: "text-white/50 text-lg" %>
  </div>
</div>
```

---

## Touch Target Sizing

### Minimum Sizes (WCAG AAA Compliance)

| Element | Minimum Size | Recommended |
|---------|--------------|-------------|
| Primary button | 56×56px | 80×80px |
| Icon button | 48×48px | 64×64px |
| Text input | 70px height | 70px height |
| Tap target spacing | 8px gap | 16px gap |

### Font Sizes

| Element | Size | Weight |
|---------|------|--------|
| Page title (H1) | 2.5-4rem | 800 (extrabold) |
| Section title (H2) | 2rem | 700 (bold) |
| Button text | 1.5rem | 700 (bold) |
| Input text | 1.25rem | 400 (normal) |
| Label text | 1.25rem | 700 (bold) |
| Body text | 1rem-1.125rem | 400 (normal) |

---

## Virtual Keyboard

The touch layout (`touch.html.erb`) includes a **universal web-based virtual keyboard** that appears automatically on input focus.

### Features

- ✅ Appears on focus (text, email, password, textarea fields)
- ✅ Integrated preview (shows what you're typing)
- ✅ Special character toggle (@ → . → -)
- ✅ Enter key (submits forms)
- ✅ Hide button (dismisses keyboard)
- ✅ Audio feedback (beep on key press)
- ✅ Viewport-aware positioning

### Keyboard Layout

```
┌────────────────────────────────────────────────────┐
│ [1][2][3][4][5][6][7][8][9][0]                    │
│ [q][w][e][r][t][y][u][i][o][p]                    │
│  [a][s][d][f][g][h][j][k][l]                      │
│ [⇧][z][x][c][v][b][n][m][_]                       │
│ [typing here|] [@] [space] [,] [⌫] [↵] [Hide]     │
└────────────────────────────────────────────────────┘
```

### Usage

**No additional code needed** - keyboard appears automatically. Just ensure:
- Input has proper `type` attribute (`text`, `email`, `password`)
- Input has `id` and `name` attributes
- Form has `action` or uses `form_with`

### Preview Bar

The preview bar is integrated into the keyboard (left side of bottom row):
- Shows actual text for text/email inputs
- Shows bullets (`•••`) for password inputs
- Updates in real-time as you type
- Scrolls horizontally for long text

---

## Testing Touch Views

### Local Testing (Desktop Browser)

1. Add `?touch=1` to any URL:
   ```
   http://localhost:3005/?touch=1
   http://localhost:3005/sign-in?touch=1
   http://localhost:3005/admin?touch=1
   ```

2. Resize browser to 800×480 or use DevTools device emulation

3. Enable touch simulation in DevTools

4. Test all interactions:
   - Tap buttons (check visual feedback)
   - Focus inputs (keyboard should appear)
   - Type using keyboard (preview updates)
   - Submit forms (Enter key works)
   - Navigate back (back button works)
   - Sign out (sign out button works)

### Kiosk Testing (Raspberry Pi)

See `AGENTS.md` - `@kiosk` agent for remote control commands.

**Quick test workflow:**
```bash
# 1. Commit and push changes
git add .
git commit -m "Update touch view"
git push

# 2. Wait for GitHub Actions deployment (3-5 min)

# 3. Restart kiosk
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# 4. View logs
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -f"

# 5. Take screenshot
ssh rege@pi5cam.local "WAYLAND_DISPLAY=wayland-1 weston-screenshooter"
```

---

## Accessibility

### Touch-Specific Considerations

- ✅ **Large targets**: All interactive elements ≥56px
- ✅ **Clear spacing**: Minimum 8px between tap targets
- ✅ **Visual feedback**: Active states on all buttons
- ✅ **Audio feedback**: Beep on key press (optional)
- ✅ **High contrast**: White on dark backgrounds
- ✅ **Clear labels**: Bold, large font for all form labels

### Future Improvements

- [ ] Add `aria-label` attributes
- [ ] Screen reader announcements
- [ ] Haptic feedback (vibration API)
- [ ] High contrast mode toggle
- [ ] Keyboard layout switching (numeric/email)

---

## Common Patterns

### Action Button with Icon
```erb
<%= link_to some_path, class: "touch-btn touch-btn-primary" do %>
  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2.5rem; height: 2.5rem;">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
  </svg>
  <span>Create New</span>
<% end %>
```

### Icon-Only Button
```erb
<%= link_to back_path, class: "touch-btn-icon" do %>
  <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2.5rem; height: 2.5rem;">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
  </svg>
<% end %>
```

### Form Input
```erb
<div>
  <label for="email_address" class="touch-label">Email</label>
  <%= form.email_field :email_address, 
      required: true, 
      autocomplete: "username", 
      inputmode: "email",
      placeholder: "your@email.com", 
      class: "touch-input",
      id: "email_address" %>
</div>
```

### Stats Card
```erb
<div class="bg-white rounded-2xl shadow-xl p-6">
  <div class="flex items-center justify-center mb-3">
    <div class="w-16 h-16 bg-ismf-blue rounded-xl flex items-center justify-center">
      <svg class="w-10 h-10 text-white"><!-- icon --></svg>
    </div>
  </div>
  <div class="text-center">
    <p class="text-lg font-bold text-ismf-gray mb-1">Label</p>
    <p class="text-5xl font-extrabold text-ismf-navy">42</p>
  </div>
</div>
```

---

## Checklist for New Touch Views

Before marking a touch view as complete:

- [ ] File named `*.touch.html.erb`
- [ ] Back button present (unless root page)
- [ ] Sign out button present (if authenticated)
- [ ] Desktop mode toggle in footer
- [ ] All buttons use `touch-btn` classes
- [ ] All inputs use `touch-input` class
- [ ] Labels use `touch-label` class
- [ ] Font sizes are large (1.25rem+)
- [ ] Buttons are at least 56px tall
- [ ] Spacing between elements is adequate
- [ ] Page tested with `?touch=1` on desktop
- [ ] Keyboard appears on input focus
- [ ] Enter key submits form
- [ ] Visual feedback on button press
- [ ] Navigation flow is logical
- [ ] Content fits within 800×480 viewport

---

## Related Documentation

- **Virtual Keyboard**: `docs/VIRTUAL_KEYBOARD.md`
- **Architecture**: `docs/ARCHITECTURE.md`
- **Kiosk Agent**: `AGENTS.md` - `@kiosk`
- **Development Commands**: `docs/DEV_COMMANDS.md`
- **Project Rules**: `.rules` - Section 15

---

## Support

For questions or issues with touch display views:

1. Check this document first
2. Review existing `.touch.html.erb` files for patterns
3. Test locally with `?touch=1`
4. Use `@kiosk` agent for remote testing

---

**Last Updated**: 2024  
**Maintainer**: ISMF Race Logger Team  
**Status**: ✅ Production Ready