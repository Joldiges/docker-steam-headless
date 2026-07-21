# TL;DR: `xorg-display-fix`

This branch is the upstream [Steam Headless](https://github.com/Steam-Headless/docker-steam-headless) image with a small Xorg fix for machines that have a GPU but no connected HDMI/DisplayPort display.

## What changed

- When no physical monitor is reported, the container now selects the existing Xorg dummy driver even when an NVIDIA GPU is present. This is the important headless-display fix.
- After dummy Xorg starts, the container adds and selects the configured RandR mode using the existing `DISPLAY_SIZEW`, `DISPLAY_SIZEH`, and `DISPLAY_REFRESH` variables. This allows modes such as `2560x1600 @ 120Hz` without changing the normal upstream configuration model.
- Sunshine capture, encoder, and output selection remain automatic. The fork does not force KMS, Wayland, X11, software encoding, NVENC, or VAAPI.

## What did not change

The desktop, Steam startup, application installation, Sunshine configuration UI, and upstream environment-variable defaults remain unchanged. Bolt, display-management menus, and other convenience features are not part of this minimal fork.

The branch was based on upstream `master` at commit `096fc4b` and currently contains only the Xorg/display changes above.

## Build and publish

Debian image:

```sh
podman build -f Dockerfile.debian -t jamesoldiges/steam-headless:xorg-display-fix .
podman push jamesoldiges/steam-headless:xorg-display-fix
```

The published image is:

```text
docker.io/jamesoldiges/steam-headless:xorg-display-fix
```

## Unraid notes

For Moonlight input and discovery, use host networking. The working test also used explicit `/dev/uinput` access and the device/capability mappings from the upstream template, with `Privileged` disabled. Use an unused X display number (the current test uses `:56`).

The Sunshine UI is served at `https://<unraid-ip>:47990` and noVNC at `http://<unraid-ip>:8083`. Sunshine uses a self-signed certificate, so the browser warning is expected.

Hardware encoding is still selected automatically. NVIDIA requires the Unraid NVIDIA runtime/driver configuration; AMD and Intel require the relevant `/dev/dri` access. If no usable hardware encoder is available, Sunshine can fall back to software encoding.

The live Unraid test also used persistent user-appdata startup overrides to prevent optional application installation and `light-locker` from delaying or restarting the desktop. Those are deployment-specific workarounds and are not additional image changes in this minimal fork.
