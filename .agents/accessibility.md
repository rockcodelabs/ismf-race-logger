# Accessibility Patterns (37signals Style)

Reference guide for ARIA patterns, keyboard navigation, and screen reader support extracted from 37signals' Fizzy codebase.

---

## ARIA Patterns

### 1. Hide Decorative Elements with `aria-hidden`

Hide purely decorative or redundant visual elements from screen readers.

```erb
<!-- Before: Screen reader announces image AND text -->
<div class="bubble__image">
  <%= image_tag bubble.image %>
</div>

<!-- After: Only meaningful content is announced -->
<div class="bubble__image">
  <%= image_tag bubble.image, aria: { hidden: true } %>
</div>
```

**When to use:**
- Decorative icons next to text labels
- Avatar images when the person's name is already present
- Visual separators (horizontal rules)
- Duplicate links (e.g., clickable card + title link)

```erb
<!-- Hide duplicate navigation -->
<%= link_to collection_path, aria: { hidden: true }, tabindex: -1 do %>
  <div class="visual-preview">...</div>
<% end %>
```

### 2. Provide `aria-label` for Icon-Only Buttons

Add descriptive labels to buttons/links that only contain icons.

```erb
<!-- Before: Screen reader says "button" with no context -->
<button class="btn">
  <%= image_tag "plus.svg" %>
</button>

<!-- After: Screen reader says "Boost button" -->
<button class="btn" aria-label="Boost">
  <%= image_tag "plus.svg", aria: { hidden: true } %>
</button>
```

**Alternative pattern with visually-hidden text:**
```erb
<button class="btn">
  <%= icon_tag "trash" %>
  <span class="for-screen-reader">Delete comment</span>
</button>
```

### 3. Use `role="group"` with `aria-label` for Related Content

Group related interactive elements semantically.

```erb
<!-- Messages section -->
<div class="comments" role="group" aria-label="Messages">
  <%= render @comments %>
</div>

<!-- Assignee avatars -->
<span class="avatars" role="group" aria-label="Assignees">
  <% assignees.each do |user| %>
    <%= avatar_tag user %>
  <% end %>
</span>
```

### 4. Announce Counts in User-Friendly Format

Convert numeric counts to readable text for screen readers.

```erb
<!-- Before: "5" -->
<span><%= comments.count %></span>

<!-- After: Visual shows "5", screen reader hears "5 comments" -->
<span aria-hidden="true"><%= comments.count %></span>
<span class="for-screen-reader"><%= pluralize(comments.count, "comment") %></span>
```

### 5. Add `aria-label` and `aria-description` to Dialogs

Provide context for modal dialogs and popups.

```erb
<dialog aria-label="Assigned to…" aria-description="Filter cards by assignee"
        data-dialog-target="dialog">
  <strong>Assigned to…</strong>
  <!-- dialog content -->
</dialog>
```

### 6. Use `role="button"` for Non-Button Interactive Elements

Mark clickable elements as buttons when they're not `<button>` or `<a>` tags.

```erb
<!-- Interactive span acting as a button -->
<%= tag.span reaction.content,
      role: "button",
      tabindex: 0,
      data: { action: "click->reaction-delete#reveal" } do %>
  <span class="for-screen-reader">Delete this reaction</span>
<% end %>
```

### 7. Update `aria-expanded` Dynamically

Toggle `aria-expanded` when showing/hiding content.

```javascript
// In Stimulus controller
reveal() {
  this.element.classList.toggle(this.revealClass)
  this.contentTarget.ariaExpanded = this.element.classList.contains(this.revealClass)
}
```

### 8. Replace `<menu>` with Semantic Alternatives

Use proper HTML5 elements instead of deprecated `<menu>`.

```erb
<!-- Before -->
<menu class="filter__menu">
  <li>Option 1</li>
  <li>Option 2</li>
</menu>

<!-- After -->
<div class="filter__menu" role="group" aria-label="Sort by">
  <div>Option 1</div>
  <div>Option 2</div>
</div>
```

---

## Keyboard Navigation

### 9. Prevent Default on Keyboard Shortcuts

Call `event.preventDefault()` when handling custom keyboard shortcuts.

```javascript
// In Stimulus controller
click(event) {
  if (this.#isClickable && !this.#shouldIgnore(event)) {
    event.preventDefault()  // Add this!
    this.element.click()
  }
}
```

```erb
<!-- In Stimulus action -->
data-action="keydown.ctrl+k@document->terminal#focus:prevent"
```

### 10. Reusable Navigable List Controller

Create a Stimulus controller for arrow key navigation through lists.

```javascript
// navigable_list_controller.js
export default class extends Controller {
  static targets = ["item"]
  static values = {
    reverseNavigation: { type: Boolean, default: false },
    actionableItems: { type: Boolean, default: false }
  }

  navigate(event) {
    if (event.key === "ArrowDown") {
      this.#selectNext()
    } else if (event.key === "ArrowUp") {
      this.#selectPrevious()
    } else if (event.key === "Enter" && this.actionableItemsValue) {
      this.#activateSelected()
    }
  }

  #selectNext() {
    const items = this.#visibleItems
    const currentIndex = items.findIndex(item =>
      item.hasAttribute("aria-selected"))
    const nextIndex = (currentIndex + 1) % items.length
    this.#select(items[nextIndex])
  }

  #select(item) {
    this.itemTargets.forEach(i => i.removeAttribute("aria-selected"))
    item.setAttribute("aria-selected", "true")
    item.focus()
  }

  get #visibleItems() {
    return this.itemTargets.filter(item => {
      return item.checkVisibility() && !item.hidden
    })
  }
}
```

Usage:
```erb
<div data-controller="navigable-list"
     data-action="keydown->navigable-list#navigate">
  <div data-navigable-list-target="item">Option 1</div>
  <div data-navigable-list-target="item">Option 2</div>
</div>
```

### 11. Support Reverse Navigation Direction

Allow arrow keys to work in reverse (e.g., in trays that stack bottom-to-top).

```erb
<!-- Notifications tray stacks from bottom up -->
<dialog data-controller="navigable-list"
        data-navigable-list-reverse-navigation-value="true">
  <!-- Arrow Down goes to visually lower item -->
</dialog>
```

### 12. Reset Selection When Dialogs Open

Clear list selection when a dialog opens.

```erb
<dialog data-action="dialog:show@document->navigable-list#reset">
  <!-- List items reset when dialog opens -->
</dialog>
```

---

## Screen Reader Considerations

### 13. Use `.visually-hidden` / `.for-screen-reader` Pattern

CSS class that hides content visually but keeps it for screen readers.

```css
.visually-hidden,
.for-screen-reader {
  block-size: 1px;
  clip-path: inset(50%);
  inline-size: 1px;
  overflow: hidden;
  position: absolute;
  white-space: nowrap;
}
```

```erb
<button>
  <%= icon_tag "edit" %>
  <span class="for-screen-reader">Edit comment</span>
</button>
```

### 14. Prefer Visually Hidden Over `aria-label` for Complex Content

Use visually-hidden text instead of `aria-label` when content includes formatting.

```erb
<!-- Bad: aria-label doesn't support HTML -->
<div aria-label="Due on January 5, 2024">
  <%= local_datetime_tag due_on %>
</div>

<!-- Good: Preserve semantic date markup -->
<div>
  <div class="for-screen-reader">
    Due on <%= local_datetime_tag due_on, style: :longdate %>
  </div>
  <div aria-hidden="true">
    <%= local_datetime_tag due_on, style: :shortdate %>
  </div>
</div>
```

### 15. Fix Form Label Associations

Ensure form labels correctly reference their inputs using proper `for` attributes.

```erb
<!-- Before: Broken association with array names -->
<%= form.check_box "assignee_ids[]", {}, user.id %>
<%= form.label "assignee_ids[]", user.name,
      for: dom_id(user, :filter) %>

<!-- After: Use form builder's field_id helper -->
<%= form.check_box :assignee_ids, { multiple: true }, user.id %>
<%= form.label :assignee_ids, user.name,
      for: form.field_id(:assignee_ids, user.id) %>
```

### 16. Add Labels to Unlabeled Form Controls

Every input needs an accessible label.

```erb
<!-- Before: No label -->
<%= text_field_tag :boost_count, value %>

<!-- After: Has aria-label -->
<%= text_field_tag :boost_count, value,
      aria: { label: "Boost count" } %>
```

### 17. Use Semantic HTML Over Generic Containers

Use `<h1>`, `<h2>`, `<nav>`, `<article>` instead of `<div>` when appropriate.

```erb
<!-- Before: Missing semantic structure -->
<div class="comment__author">
  <strong><%= link_to creator.name, user_path(creator) %></strong>
  <%= link_to created_at %>
</div>

<!-- After: Proper heading -->
<h3 contents>
  <strong><%= link_to creator.name, user_path(creator) %></strong>
  <%= link_to created_at %>
</h3>
```

### 18. Provide Context for Date Pickers

Label date inputs clearly, even when visually represented.

```erb
<label class="bubble__date">
  <span class="for-screen-reader">Change the due date</span>
  <span class="bubble__date-text" aria-hidden="true">
    <%= bubble.due_on.strftime("%b <br> %d").html_safe %>
  </span>
  <%= form.date_field :due_on, class: "input--hidden" %>
</label>
```

---

## Focus Management

### 19. Consistent Focus Ring Styles

Use CSS custom properties for global focus styling.

```css
:root {
  --focus-ring-color: var(--color-link);
  --focus-ring-offset: 1px;
  --focus-ring-size: 2px;
}

:is(a, button, input, textarea):where(:focus-visible) {
  border-radius: 0.25ch;
  outline: var(--focus-ring-size) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}
```

### 20. Only Show Focus Rings for Keyboard Navigation

Use `:focus-visible` instead of `:focus`.

```css
/* Bad: Shows ring on mouse click */
button:focus {
  outline: 2px solid blue;
}

/* Good: Only shows for keyboard */
button:focus-visible {
  outline: var(--focus-ring-size) solid var(--focus-ring-color);
}
```

### 21. Hide Focus on Radio/Checkbox Wrappers

Move focus styling to the parent container when inputs are visually hidden.

```css
.btn {
  :is(input[type=radio], input[type=checkbox]) {
    appearance: none;
    position: absolute;
    inset: 0;

    &:focus-visible {
      outline: none; /* Hide on input */
    }
  }

  /* Show on parent instead */
  &:has(input:focus-visible) {
    outline: var(--focus-ring-size) solid var(--focus-ring-color);
  }
}
```

### 22. Add `.hide-focus-ring` Utility for Special Cases

Provide a way to suppress focus rings when they're visually distracting.

```css
.hide-focus-ring {
  --focus-ring-size: 0;
}
```

### 23. Manage Focus in Custom Dialogs

Focus first interactive element when dialog opens; trap focus inside dialog.

```javascript
// In dialog controller
open() {
  this.dialogTarget.showModal()
  this.#focusFirstElement()
  this.#trapFocus()
}

#focusFirstElement() {
  const firstInput = this.dialogTarget.querySelector('input, button')
  firstInput?.focus()
}
```

### 24. Use `aria-selected` for Custom List Navigation

Mark the currently selected item with `aria-selected` in navigable lists.

```css
[aria-selected] {
  outline: var(--focus-ring-size) solid var(--focus-ring-color);
  background-color: var(--color-selected);
}
```

```javascript
select(item) {
  this.itemTargets.forEach(i => i.removeAttribute('aria-selected'))
  item.setAttribute('aria-selected', 'true')
}
```

### 25. Suppress Focus on Readonly Inputs

Disable focus rings on readonly fields.

```css
input[readonly] {
  --focus-ring-size: 0;
}
```

---

## Platform-Specific Considerations

### 26. Adapt Keyboard Shortcuts by Platform

Display platform-appropriate modifier keys (Cmd vs Ctrl).

```ruby
def hotkey_label(hotkey)
  hotkey.map do |key|
    if key == "ctrl" && platform.mac?
      "⌘"
    elsif key == "enter"
      platform.mac? ? "return" : "enter"
    else
      key.capitalize
    end
  end.join("+").gsub(/⌘\+/, "⌘")
end
```

```erb
<kbd><%= hotkey_label(["ctrl", "k"]) %></kbd>
<!-- Mac: ⌘K -->
<!-- Linux/Windows: Ctrl+K -->
```

### 27. Support Both Mouse and Touch Interactions

Use `@media (any-hover: hover)` for hover effects.

```css
@media (any-hover: hover) {
  button:hover {
    filter: brightness(0.9);
  }
}

/* Touch users get the feature without hover */
button:active {
  filter: brightness(0.9);
}
```

---

## Common Patterns

### Accessible Filter/Search Dialog

```erb
<div data-controller="filter navigable-list"
     data-action="keydown->navigable-list#navigate
                  filter:changed->navigable-list#reset
                  dialog:show@document->navigable-list#reset">

  <%= text_field_tag :search, nil,
        placeholder: "Filter…",
        autofocus: true,
        data: { action: "input->filter#filter" } %>

  <ul data-filter-target="list">
    <% items.each do |item| %>
      <li data-filter-target="item"
          data-navigable-list-target="item">
        <%= button_to item_path(item),
              class: "btn popup__item" do %>
          <span><%= item.name %></span>
        <% end %>
      </li>
    <% end %>
  </ul>
</div>
```

### Accessible Avatar Pattern

```erb
<% def avatar_tag(user, hidden_for_screen_reader: false) %>
  <%= link_to user_path(user),
        title: user.name,
        class: "btn avatar",
        aria: {
          hidden: hidden_for_screen_reader,
          label: user.name
        },
        tabindex: hidden_for_screen_reader ? -1 : nil do %>
    <%= avatar_image_tag(user) %>
  <% end %>
<% end %>

<!-- Usage: When name is already announced -->
<div>
  <%= avatar_tag(user, hidden_for_screen_reader: true) %>
  <span><%= user.name %></span>
</div>
```

### Accessible Tray/Drawer Pattern

```erb
<section class="tray" data-controller="dialog">
  <dialog data-controller="navigable-list"
          data-navigable-list-reverse-navigation-value="true"
          data-action="keydown->navigable-list#navigate
                       dialog:show@document->navigable-list#reset
                       keydown.esc->dialog#close">
    <% items.each do |item| %>
      <div data-navigable-list-target="item">
        <%= render item %>
      </div>
    <% end %>
  </dialog>

  <button data-action="dialog#toggle
                       keydown.n@document->hotkey#click"
          data-controller="hotkey"
          aria-label="Toggle notifications"
          aria-haspopup="true">
    Notifications <kbd>N</kbd>
  </button>
</section>
```

---

## Quick Wins Checklist

- [ ] Add `aria-hidden="true"` to decorative icons
- [ ] Add `.for-screen-reader` labels to icon-only buttons
- [ ] Use `aria-label` on dialogs
- [ ] Replace visual counts with `pluralize()` for screen readers
- [ ] Fix form label `for` attributes with `form.field_id()`
- [ ] Implement `:focus-visible` instead of `:focus`
- [ ] Add `event.preventDefault()` to keyboard shortcuts
- [ ] Use semantic HTML (`<h1>`, `<nav>`, etc.)
- [ ] Test with keyboard-only navigation (Tab, Enter, Arrows)
- [ ] Run Lighthouse accessibility audit

---

## Testing Accessibility

### Write Unit Tests for Helper Methods

```ruby
# test/helpers/hotkeys_helper_test.rb
class HotkeysHelperTest < ActionView::TestCase
  test "mac modifier key" do
    emulate_mac
    assert_equal "⌘J", hotkey_label(["ctrl", "J"])
  end

  test "linux modifier key" do
    emulate_linux
    assert_equal "Ctrl+J", hotkey_label(["ctrl", "J"])
  end
end
```

### Test with Actual Screen Readers

- Mac: Cmd+F5 to enable VoiceOver
- Navigate with Tab, Shift+Tab
- Interact with VO+Space
- Read content with VO+A

### Use Browser DevTools Accessibility Inspector

- Chrome DevTools > Elements > Accessibility pane
- Firefox DevTools > Accessibility Inspector
- Lighthouse Accessibility audit

---

## Resources

- [ARIA Authoring Practices Guide (APG)](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM Screen Reader Testing](https://webaim.org/articles/screenreader_testing/)
- [MDN Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)