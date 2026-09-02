# Optional: matching file-manager colours

Copy `gtk.css.tpl` into your Omarchy template directory and point GTK at whichever
theme is active:

```sh
mkdir -p ~/.config/omarchy/themed
cp gtk.css.tpl ~/.config/omarchy/themed/gtk.css.tpl
ln -sf ~/.local/state/omarchy/current/theme/gtk.css ~/.config/gtk-4.0/gtk.css
omarchy theme set "$(omarchy theme current)"   # regenerate with the template in place
nautilus -q                                    # GTK reads its CSS at startup
```

This is machine-level: it applies to **every** installed theme, stock ones included,
not just Levantine Sunset. To undo it, delete both paths.
