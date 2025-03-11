# Inline JavaScript Checklist

This document lists all views in the resume application that contain inline JavaScript.

## Views with Inline JavaScript

- [x] app/views/layouts/side_by_side.html.erb
  - Lines 40-101
  - Purpose: Controls responsive behavior of the chat panel

- [x] app/views/chat/_chat_panel.html.erb
  - Lines 69-219
  - Purpose: Handles chat functionality, carousel navigation, and AJAX requests

- [x] app/views/chat/index.html.erb
  - Lines 77-218
  - Purpose: Similar to _chat_panel.html.erb, handles chat interface when viewed directly

## Notes

- All JavaScript is defined directly within `<script>` tags in the templates
- No separate JavaScript files were found in the application
- No use of Rails' `javascript_tag` or `javascript_include_tag` helpers was found
- No Stimulus.js controllers were detected

## Recommendations

Consider moving inline JavaScript to separate files for better maintainability:

- [ ] Extract side_by_side.html.erb JavaScript to a dedicated file
- [ ] Extract _chat_panel.html.erb JavaScript to a dedicated file
- [ ] Extract chat/index.html.erb JavaScript to a dedicated file
- [ ] Use Rails' asset pipeline or import maps to manage these JavaScript files 