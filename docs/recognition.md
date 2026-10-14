# Recognition version 0.2

## Workflow

1. Update the installed app with the new IPA using AltStore Classic, retaining the broadcast extension and App Group. Updating with the same Apple account/app identity should preserve app data; removing the app can delete the collection.
2. Open **Scan**. If shared storage is unavailable, resolve the signing/App Group issue before trying live recognition. Screenshot imports still work locally in the host app.
3. Start the broadcast. Open a Pokémon detail page with its species name visible and hold it for 3–5 seconds. The scanner needs two consistent name observations before creating a live record.
4. Open appraisal, then the unobstructed moves page. Keep each page steady for 3–5 seconds. A nearby moves-only page can enrich the active record if there is no conflicting species/CP/max HP/IV evidence.
5. Return to **Pokémon**. The app imports the extension's atomic JSON snapshots, saves them in its own collection, and shows missing fields as **Not detected**. Tap a row to inspect it.
6. Stop the system broadcast. Records remain after stopping, closing the app, and reopening it.

Use **Import a screenshot** to process one image without broadcasting. Imported images are analyzed off the main UI thread and discarded after recognition. A known species is saved even if CP, HP, moves, or IVs are absent. The species must be on a recognizable Pokémon detail/appraisal screen, not an arbitrary photo containing a Pokémon name.

## Fields and limitations

| Field | Current method | Missing/ambiguous behavior |
| --- | --- | --- |
| Species | Apple Vision text matched to bundled English/Italian species names; can also use readable appraisal prose | No 3D-model classifier; a nickname alone is not enough. Form-specific identities are not distinguished yet. |
| CP | CP/PC label and number near the top of the detail screen | Values outside the expected range or absent labels remain missing. |
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
- Outbox snapshots remain in the shared group; they are not removed during import. This avoids cross-process read/delete races and means storage grows with the number of scans. Cleanup/export/editing are future work.
- No screenshots, videos, raw OCR transcript, Apple credentials, or network uploads are stored by recognition. Only recognized Pokémon fields and timestamps are persisted.

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

Device acceptance: import the example, confirm the expected values/missing moves, relaunch to verify persistence, then scan two different-CP Pokémon and inspect separate records. Test detail → appraisal → moves enrichment, end the broadcast while Pokémon GO is open, and confirm its saved snapshots import when the host app reopens. Report wrong IVs with an unobscured screenshot and exact iPhone/iOS/signing-tool versions.

The pinned name catalog comes from PokéAPI, not the Pokémon GO game master. It is bundled for offline recognition; its source revision and languages are recorded in `ios/Resources/pokemon-catalog.json`. Required redistribution terms are in `docs/third-party/PokeAPI-LICENSE.txt` and also ship in both app bundles.
