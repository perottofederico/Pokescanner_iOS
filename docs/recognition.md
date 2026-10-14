# Recognition and collection version 0.3

## Workflow

1. Update the installed app with the new IPA using AltStore Classic, retaining the broadcast extension and App Group. Updating with the same Apple account/app identity should preserve app data; removing the app can delete the collection.
2. Open **Scan**. If shared storage is unavailable, resolve the signing/App Group issue before trying live recognition. Screenshot imports still work locally in the host app.
3. Start the broadcast. Open a Pokémon detail page with its species name visible and hold it for 3–5 seconds. The scanner needs two consistent name observations before creating a live record.
4. Open appraisal, then the unobstructed moves page. Keep each page steady for 3–5 seconds. A nearby moves-only page can enrich the active record if there is no conflicting species/CP/max HP/IV evidence.
5. Return to **Pokémon**. The app imports the extension's atomic JSON snapshots, saves them in its own collection, and shows missing fields as **Not detected**. Tap a row to inspect it.
6. Stop the system broadcast. Records remain after stopping, closing the app, and reopening it.

Use **Import a screenshot** to process one image without broadcasting. Imported images are analyzed off the main UI thread; the full image is discarded after recognition, but a small cropped Pokémon thumbnail is retained. A known species is saved even if CP, HP, moves, or IVs are absent. The species must be on a recognizable Pokémon detail/appraisal screen, not an arbitrary photo containing a Pokémon name.

## List controls and editing

- Use the sort menu in the Pokémon tab for IV, CP, Pokédex number, scan date, or display name. IV/CP/date default to descending; number/name default to ascending. The direction can be reversed. Missing CP or incomplete IVs stay last in either direction, and sort preferences survive relaunch.
- Swipe a row to remove it, or use the trash button in details. Confirmation is required. A persistent deletion marker prevents that scan UUID from reappearing when the shared snapshots are imported again. Scanning the Pokémon again can create a new UUID and a new row.
- Open details and tap **Edit** to change species, display name, CP, current/max HP, all three IVs, and up to three moves. Species/number stay linked through the bundled catalog. Species and move entries require known full English/Italian names; display names may be customized. Leave numeric/move fields empty for unknown values. Invalid ranges and current HP above maximum HP are rejected.
- Once manually edited, a record's fields are protected from later scan snapshots. New diagnostic events and a previously missing thumbnail may still be imported. Scan time is preserved; edits change the last-updated time.
- Existing collections are migrated automatically. Older rows show placeholders for images and diagnostics until rescanned/imported; no pixels can be recovered from old scans.
- IV percentages round to the nearest whole number (half rounds up). Their circle colors use the rounded value: 0–60 grey, 61–80 blue, 81–95 green, 96–99 orange, 100 purple. Incomplete IVs show a grey dash, not zero.

## CP troubleshooting and temporary diagnostics

The original CP parser required the label and digits in one OCR line. Version 0.3 also accepts aligned separate boxes, supports CP/PC/PL labels, tolerates spaced digits, and retries missing CP on an enlarged, contrast-adjusted top-of-screen crop. Unlabelled numbers and conflicting candidates are not guessed to be CP. Live CP still needs two agreeing frames. These changes address possible causes; the actual cause on an iPhone must be confirmed from its diagnostics.

Each new scan stores up to 80 deduplicated diagnostic events (600 characters per event). Expand **Temporary scan diagnostics** in details to inspect or share the text. It includes the top OCR lines and their confidence/normalized top-left coordinates, label pairing/acceptance failures, crop retry results, frame sizes/orientation, and two-frame CP consensus. Diagnostic-only updates may save a snapshot even when no statistics change. Logs are on-device and are not uploaded automatically.

If CP is still missing, scan the detail page for 3–5 seconds, stop broadcasting, and share that row's diagnostics together with the iPhone model, iOS version, game language, and an unobscured screenshot if safe. Review the log before sharing: top-screen OCR may include notification text. Existing records without diagnostics need a new scan or screenshot import.

## Fields and limitations

| Field | Current method | Missing/ambiguous behavior |
| --- | --- | --- |
| Species | Apple Vision text matched to bundled English/Italian species names; can also use readable appraisal prose | No 3D-model classifier; a nickname alone is not enough. Form-specific identities are not distinguished yet. |
| CP | CP/PC/PL label with inline digits or nearby aligned digits, plus a top-crop retry | Values outside the expected range, absent labels, or conflicting candidates remain missing. |
| HP | Visible current/maximum HP fraction, with HP/PS/PV label | Missing or inconsistent fractions remain missing. Current HP is distinct from the stamina IV. |
| Moves | Full OCR lines matched to the bundled move-name catalog | Appraisal overlays, cut-off names, localized names that differ from the core-game catalog, or unknown moves remain missing. No inferred/default moves, fast/charged classification, or move legality checks. |
| IVs | Appraisal-label positions locate the white panel; colored fill is measured against the full bar track and quantized to 0–15 | Requires all three labels to establish an appraisal layout. Obscured, low-contrast, differently themed/layout bars, or uncertain endpoints remain missing. |

IVs are estimates from pixels, not values reverse-calculated from CP. Recognized fields are filled conservatively; later conflicting numeric observations establish a new candidate instead of silently overwriting an existing record. Two matching live name observations are required, but OCR can still make errors. This is an initial recognition implementation, not a guarantee of perfect readings.

The supplied example is expected to produce **Haxorus, CP 3583, HP 156/156, IVs 15/14/15**. Its moves are obscured, so they are deliberately left missing. GitHub Actions runs the actual Apple Vision/pixel pipeline against this image before building the IPA; Windows checks cannot substitute for that native run.

## Grouping and duplicates

Each live scan has its own UUID. Repeated unchanged frames do not create records. Nearby detail/appraisal/move observations enrich that record only when individual fields agree across two frames. A confirmed conflicting species, CP, maximum HP, or known IV begins a new candidate. A recognized non-detail/navigation frame or an extended gap clears the association. This conservative rule can split a specimen into multiple partial records if an intervening frame cannot be recognized.

Even one contradictory frame suspends enrichment: subsequent identity-less moves cannot attach to the old record. Two consistent frames positively matching the old species and its non-missing stored CP can restore ownership after a transient OCR error. If CP was missing or the confirmed identity conflicts, re-identification creates a separate record instead; a species name alone cannot restore an old partial record.

There is no Pokémon GO instance identifier in a screenshot. Two specimens with identical visible information cannot be reliably distinguished; repeated visits or a fresh broadcast can produce duplicates. Conversely, changing to a visually identical specimen may remain in the current record. Start a new broadcast if you need to explicitly separate indistinguishable specimens. The app deliberately does not globally merge records just because their species/CP match.

## Storage and signing

- Both app targets request `group.com.pokecapture.shared`. The extension writes one atomic JSON snapshot per detected record; the app is the only writer of its own persistent collection.
- The packaging script builds without Apple credentials, then ad-hoc signs both targets to embed the entitlement. This is not an installable developer signature: AltStore must provision and re-sign the IPA.
- AltStore's current source registers/reassigns declared App Groups and places their rewritten identifiers in `ALTAppGroups`. The app/extension read that key before falling back to the original group ID. Other signers must keep the same group accessible to both targets.
- Free-account provisioning policies/signing-tool support can vary. An App Group failure is surfaced explicitly; the scanner does not silently write live results to an inaccessible extension-only container. Never remove the App Group to bypass an install error and assume live persistence still works.
- Outbox snapshots remain in the shared group; they are not removed during import or collection deletion. Deletion removes the local collection row/image/log and persists its UUID as a tombstone, but the extension's snapshot may still hold the cropped image and diagnostics. This avoids cross-process read/delete races; shared-outbox cleanup is future work.
- New records retain a JPEG crop of the model region (longest side at most 240 pixels) and bounded top-screen OCR diagnostics in addition to fields/timestamps. Full frames, videos, audio, full-screen OCR transcripts, Apple credentials, and automatic network uploads are not retained. Cropping follows the expected detail-screen layout, not a model-segmentation classifier; avoid private notifications while scanning.

## Checks

On Windows:

```powershell
python scripts/validate-project.py
```

On macOS with Xcode (or via Actions):

```bash
mkdir -p build
xcrun swiftc -swift-version 5 ios/Shared/*.swift scripts/check-recognition.swift \
  -framework Vision -framework CoreImage -framework CoreGraphics -o build/recognition-check
./build/recognition-check
```

Device acceptance: import the example, confirm the expected values/missing moves, thumbnail, orange 98% badge, and diagnostic text. Test all five sorts in both directions, edit and clear fields, reject IV 16, relaunch to verify edits, and remove a live row while its broadcast continues (it must not resurrect on refresh). Then scan two different-CP Pokémon and inspect separate records. Test detail → appraisal → moves enrichment, end the broadcast while Pokémon GO is open, and confirm its saved snapshots import when the host app reopens. Report wrong IVs with an unobscured screenshot and exact iPhone/iOS/signing-tool versions.

The pinned name catalog comes from PokéAPI, not the Pokémon GO game master. It is bundled for offline recognition; its source revision and languages are recorded in `ios/Resources/pokemon-catalog.json`. Required redistribution terms are in `docs/third-party/PokeAPI-LICENSE.txt` and also ship in both app bundles.
