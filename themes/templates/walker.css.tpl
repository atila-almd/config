@define-color window_bg_color ${THEME_BACKGROUND};
@define-color overlay_bg_color ${THEME_BACKGROUND_ALT};
@define-color search_bg_color ${THEME_SURFACE};
@define-color result_bg_color ${THEME_SURFACE};
@define-color result_hover_color ${THEME_SURFACE_ALT};
@define-color result_selected_color ${THEME_SELECTION};
@define-color theme_fg_color ${THEME_FOREGROUND};
@define-color muted_fg_color ${THEME_FOREGROUND_MUTED};
@define-color accent_bg_color ${THEME_ACCENT};
@define-color action_hint_color ${THEME_CYAN};
@define-color error_bg_color ${THEME_RED};
@define-color error_fg_color ${THEME_BACKGROUND};
@define-color preview_border_color ${THEME_MAGENTA};

* {
  all: unset;
}

.box-wrapper {
  background: @overlay_bg_color;
  color: @theme_fg_color;
  padding: 18px;
  border: 1px solid alpha(@theme_fg_color, 0.16);
  border-radius: 28px;
  box-shadow: 0 8px 24px alpha(@window_bg_color, 0.42);
}

.search-container {
  background: @search_bg_color;
  border: 1px solid @accent_bg_color;
  border-radius: 12px;
  padding: 3px;
}

.input {
  background: @search_bg_color;
  color: @theme_fg_color;
  caret-color: @accent_bg_color;
  padding: 10px 12px;
}

.input placeholder,
.item-subtext,
.keybind-button,
.keybind-bind {
  color: @muted_fg_color;
}

.list {
  color: @theme_fg_color;
  padding-top: 8px;
}

.item-box {
  background: @result_bg_color;
  color: @theme_fg_color;
  border: 1px solid transparent;
  border-radius: 12px;
  padding: 10px;
  margin: 2px 0;
}

child:hover .item-box,
row:hover .item-box {
  background: @result_hover_color;
  border-color: @accent_bg_color;
}

child:selected .item-box,
row:selected .item-box {
  background: @result_selected_color;
  border: 2px solid @accent_bg_color;
  border-radius: 18px;
  padding: 9px;
}

.item-quick-activation,
.keybind-label {
  background: @accent_bg_color;
  color: @window_bg_color;
  border-radius: 12px;
  padding: 3px 6px;
}

.elephant-hint,
.preview-box,
.placeholder {
  color: @theme_fg_color;
}

.keybinds {
  color: @action_hint_color;
  border-top: 1px solid @result_hover_color;
  padding-top: 8px;
}

.preview {
  color: @theme_fg_color;
  border: 2px solid @preview_border_color;
  border-radius: 18px;
  padding: 8px;
}

.error {
  background: @error_bg_color;
  color: @error_fg_color;
  border-radius: 12px;
  padding: 10px;
}
