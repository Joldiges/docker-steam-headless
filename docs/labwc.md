# labwc Wayland image

The `Dockerfile.labwc` image is the Wayland headless variant. It replaces the
upstream Xfce/Xorg desktop with labwc, Xwayland, and a wlroots headless output.
Sunshine uses `wlr` capture in this image. On NVIDIA hosts, pair it with the
`nvenc` encoder; do not use `nvfbc`, which is an Xorg capture backend.

Build locally:

```sh
docker build -f Dockerfile.labwc -t steam-headless:labwc .
```

For Compose, set `STEAM_HEADLESS_IMAGE=steam-headless:labwc` in `.env` and use
the existing NVIDIA or AMD/Intel template. The NVIDIA template should also set:

```dotenv
SUNSHINE_CAPTURE=wlr
SUNSHINE_ENCODER=nvenc
```

The container remains persistent across restarts through the existing
`HOME_DIR` and `GAMES_DIR` mounts. `ENABLE_STEAM=true` starts Steam inside the
labwc session; `ENABLE_SUNSHINE=true` starts Sunshine under supervisord.
