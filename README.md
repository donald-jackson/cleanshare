# CleanShare

**Strip identifying metadata from photos and videos before you share them.**

<!-- TODO: TestFlight badge -->
<!-- TODO: App Store badge -->
<!-- TODO: GitHub Actions badge -->
<!-- TODO: License badge -->

![CleanShare launch screen](screenshots/dev/1.26-app-launch.png "CleanShare launch screen — placeholder UI, polished art arrives in the 4.x milestone")

## What it does

CleanShare is a free and open-source iOS app that inserts itself into the system share sheet. When you share a photo or video, it removes location, camera, and timestamp metadata from the file first, then re-presents the share sheet so you can send the cleaned copy to any app you like. Everything happens on-device — there is no backend, no analytics, and no network access.

## What gets stripped

By default CleanShare removes every metadata family that can identify you or your device:

- **EXIF** — GPS, capture date/time, camera Make/Model, lens, ISO, exposure (date and Make/Model are preservable via Settings).
- **GPS IFD** — hard "no" by default; re-enabling requires an explicit Settings opt-in with a confirmation prompt.
- **MakerNote** — Apple, Canon, Nikon, Sony, Fuji, Olympus, Pentax, Minolta. `MakerApple` is the biggest threat because it carries Live Photo pairing UUIDs.
- **IPTC / XMP** — including Photoshop and IPTC-XMP packets.
- **TIFF IFD0** — Software, ImageDescription, Artist, Copyright, etc.
- **PNG ancillary chunks** (tEXt, iTXt, zTXt, eXIf, tIME), **GIF/WebP EXIF & XMP** blocks.
- **QuickTime `mdta` / `udta` metadata atoms** and **per-track timed-metadata tracks**.

## What gets preserved

Only the data needed to render the file correctly is kept:

- **ICC color profile** — preserved by default for color correctness; toggleable off in Settings.
- **Orientation** — preserved so the image displays the right way up.
- **Codec format descriptions** — pixel/frame dimensions, duration, and codec structure stay intact.

## Install

<!-- TODO: TestFlight badge -->

CleanShare will be distributed via TestFlight and the App Store once it ships.

### Build from source

Clone the repo and run the contributor bootstrap script:

```bash
./scripts/bootstrap.sh
```

It installs the toolchain, generates the Xcode project, and gets you to a buildable state. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

## Privacy

CleanShare collects no data. See [`PRIVACY.md`](PRIVACY.md) for the full privacy posture.

## Threat model

What CleanShare does and does not defend against is documented in [`docs/threat-model.md`](docs/threat-model.md).

## Contributing

Contributions are welcome. Start with [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT.
