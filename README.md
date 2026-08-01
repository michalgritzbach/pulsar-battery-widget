# waybar-pulsar-battery

A [Waybar](https://github.com/Alexays/Waybar) custom module that shows the
battery level of a Pulsar wireless gaming mouse connected through the
Pulsar LINK 2 dongle.

Tested with the **Pulsar Feinmann F01** and the LINK 2 dongle
(`3710:5504`). Other Pulsar mice paired to the same dongle will most
likely work too, since the module only talks to the dongle.

## Requirements

- Python 3 (standard library only)
- A [Nerd Font](https://www.nerdfonts.com/) for the mouse/bolt glyphs
- Read/write access to the dongle's hidraw node (see below)

## Installation

```sh
mkdir -p ~/.config/waybar/scripts
cp pulsar-battery.py ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/pulsar-battery.py
```

### Permissions

On most distributions hidraw nodes are root-only. Install the bundled
udev rule to grant access to the locally logged-in user:

```sh
sudo cp 99-pulsar-link2.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

Then re-plug the dongle. You can verify with:

```sh
~/.config/waybar/scripts/pulsar-battery.py
```

which should print a JSON line with the current battery level.

### Waybar config

Add the module to `~/.config/waybar/config.jsonc`:

```jsonc
"modules-right": [ /* ... */ "custom/pulsar-battery" /* ... */ ],

"custom/pulsar-battery": {
  "exec": "~/.config/waybar/scripts/pulsar-battery.py",
  "interval": 60,
  "return-type": "json",
  "format": "{}",
  "tooltip": true
}
```

And the colors to `~/.config/waybar/style.css`:

```css
#custom-pulsar-battery.charging {
  color: #a6e3a1;
}

#custom-pulsar-battery.critical,
#custom-pulsar-battery.disconnected {
  color: #f38ba8;
}
```

Restart Waybar. The tooltip shows the charge state and cell voltage;
the module hides itself entirely when the dongle is unplugged.

## Notes

- If Pulsar's [Bibimbap](https://support.pulsar.gg/hc/en-us/articles/58653339537177-How-can-I-use-the-web-driver-Bibimbap)
  web driver is open in a browser tab at the same time, it may
  occasionally consume a response; the script retries up to three times,
  but closing the tab helps if you see `󰍽 ?`.
- Polling once a minute has no measurable effect on the mouse's battery.

## Credits

The HID protocol details come from Nikolas Koesling's proposed
[`hid-pulsar` kernel driver](https://ratatoskr.run/linux-input/2026/04/3494264).

## License

[MIT](LICENSE)
