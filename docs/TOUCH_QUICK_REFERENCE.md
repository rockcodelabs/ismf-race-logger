# Touch Display Quick Reference

## 🎯 Target Device
- **Display**: Raspberry Pi Touch Display 2 (800×480)
- **Device**: pi5cam.local (Raspberry Pi 5)
- **Browser**: Chromium in kiosk mode
- **Compositor**: Weston (Wayland)

---

## 📁 File Naming

Touch views use `.touch.html.erb` suffix:
```
app/views/home/index.touch.html.erb
app/views/sessions/new.touch.html.erb
app/views/admin/dashboard/index.touch.html.erb
```

Rails automatically selects when `request.variant = :touch`

---

## 🎨 Page Template

```erb
<% content_for :page_title, "Your Page Title" %>

<div class="min-h-screen touch-spacing">
  <h1 class="text-4xl font-extrabold text-white mb-8 text-center">
    Your Page Title
  </h1>
  
  <!-- Your content here -->
</div>
```

### Home Page Template (Special)
```erb
<div class="min-h-screen flex flex-col items-center justify-between py-8 px-6">
  <div class="flex-1 flex flex-col items-center justify-center w-full">
    <!-- Content -->
  </div>
  <div class="w-full text-center pb-4">
    <!-- Footer -->
  </div>
</div>
```

---

## 🧭 Navigation Bar (Automatic)

Navigation bar appears on **all pages except home**.

### Features
- **Hamburger menu** (☰) - Toggle show/hide
- **Home button** (🏠) - Go to root
- **Back button** (←) - Browser history back
- **Page title** - Centered text
- **Sign Out** (→) - Log out (authenticated only)

### Behavior
- Auto-hides when scrolling down (>100px)
- Auto-shows when scrolling up
- Floating hamburger appears when hidden
- Tap hamburger to collapse/expand

**You don't need to add navigation yourself!** Just set page title:
```erb
<% content_for :page_title, "Dashboard" %>
```

---

## 🎹 Virtual Keyboard (Automatic)

Appears automatically on input focus.

### Layout
```
[1][2][3][4][5][6][7][8][9][0]
[q][w][e][r][t][y][u][i][o][p]
 [a][s][d][f][g][h][j][k][l]
[⇧][z][x][c][v][b][n][m][_]
[typing here|] [@] [space] [,] [⌫] [↵] [Hide]
```

### Features
- **Preview** - Shows typed text (left side)
- **Special chars** - Toggle @ → . → -
- **Enter key** (↵) - Submits form (green)
- **Hide button** - Dismisses keyboard (red)
- **Audio feedback** - Beep on key press

### For Forms
Add extra bottom padding for keyboard clearance:
```erb
<div class="min-h-screen touch-spacing pb-32">
  <!-- Form content -->
</div>
```

---

## 🎨 CSS Classes

### Buttons
| Class | Size | Color | Usage |
|-------|------|-------|-------|
| `touch-btn` | 80px height | Base | All buttons |
| `touch-btn-primary` | 80px height | Red gradient | Primary actions |
| `touch-btn-secondary` | 80px height | Blue gradient | Secondary actions |
| `touch-btn-icon` | 64×64px | Transparent | Icon-only (deprecated - use nav bar) |
| `touch-nav-btn` | 64×64px | Red tint | Navigation bar buttons |

### Inputs
| Class | Size | Usage |
|-------|------|-------|
| `touch-input` | 70px height, 1.25rem | Form inputs |
| `touch-label` | 1.25rem, bold | Form labels |

### Layout
| Class | Padding | Usage |
|-------|---------|-------|
| `touch-spacing` | 2rem | Page padding |
| `touch-spacing-lg` | 3rem | Large padding |
| `touch-logo` | 120×120px | Logo container |

---

## 📏 Size Guidelines

### Minimum Touch Targets
- Navigation buttons: **64×64px**
- Content buttons: **56×56px minimum**
- Spacing between targets: **16-24px**

### Font Sizes
- Page title (H1): **2.5-4rem** (40-64px)
- Section title (H2): **2rem** (32px)
- Button text: **1.5rem** (24px)
- Input text: **1.25rem** (20px)
- Labels: **1.25rem bold** (20px)

---

## ✅ Checklist for New Touch Views

- [ ] File named `*.touch.html.erb`
- [ ] Page title set with `content_for :page_title`
- [ ] No manual navigation header (nav bar is automatic)
- [ ] No "Switch to Desktop" link (already in touch mode)
- [ ] Home page uses flexbox layout (prevents footer overlap)
- [ ] Forms have `pb-32` class (keyboard clearance)
- [ ] All buttons use `touch-btn` classes
- [ ] All inputs use `touch-input` class
- [ ] Labels use `touch-label` class
- [ ] Font sizes are large (1.25rem+)
- [ ] Buttons are 56px+ tall
- [ ] Tested with `?touch=1` on desktop
- [ ] Keyboard appears on input focus
- [ ] Hide button works
- [ ] Enter key submits form

---

## 🧪 Testing

### Local (Desktop)
```bash
# Add ?touch=1 to URL
http://localhost:3005/?touch=1
http://localhost:3005/sign-in?touch=1

# Use DevTools device emulation (800×480)
# Enable touch simulation
```

### Kiosk (Pi)
```bash
# 1. Commit and push
git add . && git commit -m "Update touch UI" && git push

# 2. Wait for GitHub Actions (~3-5 min)

# 3. Restart kiosk
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# 4. View logs
ssh rege@pi5cam.local "sudo journalctl -u kiosk.service -f"
```

### Verify Touch Mode is Active
```bash
# Check kiosk URL includes ?touch=1
ssh rege@pi5cam.local "sudo cat /etc/systemd/system/kiosk.service | grep http"

# Should see: http://YOUR_IP:3005/?touch=1
```

### If Pi Shows Desktop View Instead of Touch
```bash
# 1. Verify URL has ?touch=1
ssh rege@pi5cam.local "sudo cat /etc/systemd/system/kiosk.service | grep 'http'"

# 2. If missing ?touch=1, run Ansible to update:
cd ansible
ansible-playbook -i inventory.yml update-kiosk-url.yml

# 3. Force restart with cache clear:
ssh rege@pi5cam.local "sudo systemctl restart kiosk.service"

# 4. Cookie might be set to desktop mode - wait for fresh load
# Chromium runs with --incognito so cookies clear on restart
```

---

## 🚫 Common Mistakes

### ❌ DON'T
```erb
<!-- Don't add manual navigation header -->
<div class="flex items-center justify-between">
  <%= link_to "Back", ... %>
</div>

<!-- Don't add desktop toggle -->
<%= link_to "Switch to Desktop", path(touch: 0) %>

<!-- Don't use absolute positioning for footer -->
<div class="absolute bottom-4">Footer</div>

<!-- Don't forget page title -->
<h1>My Page</h1> <!-- Missing content_for -->
```

### ✅ DO
```erb
<!-- Set page title -->
<% content_for :page_title, "My Page" %>

<!-- Use flexbox for layout -->
<div class="min-h-screen flex flex-col">
  <div class="flex-1">Content</div>
  <div>Footer</div>
</div>

<!-- Add bottom padding for forms -->
<div class="pb-32">
  <%= form_with ... %>
</div>
```

---

## 📚 Full Documentation

- **Guidelines**: `docs/TOUCH_DISPLAY_GUIDELINES.md`
- **Keyboard**: `docs/VIRTUAL_KEYBOARD.md`
- **Summary**: `docs/TOUCH_DISPLAY_SUMMARY.md`
- **Rules**: `.rules` - Section 15
- **Kiosk Agent**: `AGENTS.md` - `@kiosk`

---

## 🎉 Key Improvements

✅ **Navigation is automatic** - No manual headers needed  
✅ **Hamburger menu** - Collapsible nav bar  
✅ **Auto-hide on scroll** - Maximizes screen space  
✅ **Integrated keyboard preview** - See what you're typing  
✅ **Better spacing** - 64×64px nav buttons with gaps  
✅ **No desktop toggle** - Clean UI, no confusion  
✅ **Flexbox layouts** - No footer overlap issues  

---

**Last Updated**: 2024  
**Status**: ✅ Production Ready