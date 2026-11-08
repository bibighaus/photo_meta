# PhotoMeta

A macOS app for tagging scanned photos (`.jpg`) with capture date and
location before adding them to your collection.

## Workflow

1. **Choose Folder…** — pick a folder of scanned JPEGs.
2. Four tabs sort every photo in that folder by what it's missing:
   - **No Meta Data** — nothing set yet.
   - **Date Updated** — has a date, still needs a location.
   - **Location Updated** — has a location, still needs a date.
   - **Date and Location Updated** — fully tagged.

   A slider scales the thumbnail size. Picking a photo from any tab works
   the same way — so if you tagged a batch with just a date, you can come
   back to the **Date Updated** tab later and add locations to exactly
   those photos.
3. Click a thumbnail to see it larger. If a scan came in sideways or
   upside down, use **Rotate Left**, **Rotate Right**, or **Mirror
   Left/Right** to fix its orientation before deciding — these edit the
   photo's EXIF orientation tag, so they're instant and lossless. Then
   choose **Add to Batch** to stage it for tagging, or **Skip** to go back
   and pick a different photo.
4. Staged photos appear in a tray along the bottom. Click **Add Date &
   Location…** to open the editor:
   - **Set Date** and **Set Location** are independent toggles — turn
     either one off to leave that field untouched on the staged photos
     (e.g. add a location to a batch that already has dates, without
     resetting those dates).
   - Set a date/time with the date picker.
   - Enter a location by typing an address/place and clicking **Find**
     (geocoded via Apple's location services), or type latitude/longitude
     directly.
   - Or click **Copy Date/Location From Existing Photo…** to pick one of
     the photos you've already tagged and reuse its date and/or location.
   - **Apply** writes whichever field is turned on into each staged photo's
     EXIF/GPS metadata, which moves it into the matching tab.
5. Re-opening the same folder later (or adding new scans to it) sorts
   photos into the same four tabs — a date and a location set by this app
   are each recognized by their own marker written into the photo's IPTC
   keywords, so this works even if a scan already had some unrelated
   timestamp baked in by the scanner software.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later

## Building & Running

This is a Swift Package, not an `.xcodeproj` — that keeps the source
buildable without any generated project files to keep in sync.

- **In Xcode:** open `Package.swift` directly (`File > Open…`), select the
  `PhotoMeta` scheme, and press Run.
- **From the command line:** `swift run` (or `swift build -c release` and
  run the binary from `.build/release/PhotoMeta`).

### A note on file permissions

macOS restricts programmatic access to Desktop, Documents, Downloads and
removable/network volumes for any app, signed or not. If you point PhotoMeta
at a folder in one of those locations, macOS may need to prompt for access
the first time (via Xcode/Terminal's entry in System Settings > Privacy &
Security > Files and Folders). If the folder scan fails, check there first,
or test with a folder elsewhere in your home directory.

## How metadata is stored

PhotoMeta edits each JPEG's own EXIF/GPS/IPTC metadata directly via
ImageIO — there's no separate database or sidecar file, so the metadata
travels with the file. Only the metadata dictionary is rewritten; the
original image data is copied through untouched, so there's no quality
loss or re-compression.
