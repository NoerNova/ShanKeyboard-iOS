# Keyboard extension memory baseline

Target: peak footprint under 61 MB, with clear headroom below the ~90 MB cap
measured in June 2026. Re-confirm the cap per device with the `memory` log
category (see "Measuring on device").

## Phase 0: June 2026 findings, re-checked on 2026-11-05 (build 2.0 (1) + working tree)

| Finding | Status | How it was checked |
|---|---|---|
| PDFKit in the extension | Fixed | No `PDFKit` import in any target; not in the extension's linked frameworks (`otool -L`). |
| Memory warnings not handled | Fixed | `KeyboardViewController.didReceiveMemoryWarning` flushes Tokenizer, suggestion and dictionary search caches, and logs before/after. |
| XPC failures | Not verified | Needs a device console capture. Filter Console for the `Shan` process and `XPC`. |
| App Group preferences | Fixed | Host app and extension both declare `group.com.noernova.ShanKeyboard.shared`; shared settings go through `SharedUserDefaults` (`UserDefaults(suiteName:)`). |
| Trie and frequency data decoded into Swift objects | Fixed in this change | Dictionary and n-gram model are now read-only memory maps (`lexicon.bin`, `ngram_model.bin` v2), searched in place. |
| Syllable predictor history | Fixed in this change | The syllable Markov chain was built but never read; removed. Learned words capped at 3,000, syllable counts at 4,000. |

## Measured: autocomplete data structures

Measured on macOS (arm64, same Swift object layout as iOS) with the real
resources, each variant in a fresh process. `phys_footprint` is what Jetsam
compares against the cap.

| Variant | Resident after load | Peak during load |
|---|---|---|
| Before: TrieNode dictionary + syllable trie + copied n-gram model | 42 MB | 45.7 MB |
| After: mapped `lexicon.bin` + mapped `ngram_model.bin` | 0.1 MB | 1.9 MB (whole process) |

The mapped files are clean, file-backed pages. They do not count toward
`phys_footprint`, and iOS can drop them under pressure and fault them back in.

Behavior was checked against the old implementation on the same data: 335,736
dictionary probes (contains, prefix, top-k by frequency) and 54,000 n-gram
scoring cases all matched.

## Crash fixed in this change

`AutocompleteDataManager.buildBigramChain()` runs in the provider's init, before
the dictionary loads, when the tokenizer returns `[]` for every word. Its loop
`0..<words.count - 1` became `0..<-1`, which traps. Any user with at least one
learned word crashed the extension on a cold launch, and iOS fell back to the
default keyboard. The loops now iterate adjacent pairs and are safe for 0 or 1 words.

## Not yet done (needs a device)

- Whole-extension footprint on device: launch, each layout, emoji keyboard, after dismissal.
- The root cause of the `CALayerInvalidGeometry` (NaN bounds) crash. Reproduced on
  iPhone 16 Pro, iOS 27.2, about 15 s after launch, with no app frames in the stack.
  KeyboardKit guards key widths, its callout inset defaults to zero, and project code
  does no size division, so static reading did not find the source.
  `LayerGeometryGuard` now replaces NaN in `CALayer` bounds and position with 0, which
  stops the crash, and logs a fault naming the owning views. Find the source with:
  ```
  log stream --predicate 'subsystem == "com.noernova.ShanKeyboard.shan" AND category == "layout"'
  ```
  A suspect worth checking first: ISEmojiView's `EmojiView_SwiftUI.updateUIView` activates
  two new constraints on every SwiftUI update and never removes them.
- 10-minute soak test on the lowest-RAM supported device, iOS 26 and 27.x.

## Measuring on device

The extension logs footprint and remaining headroom at launch, dictionary load,
n-gram load, memory warning and dismissal:

```
log stream --predicate 'subsystem == "com.noernova.ShanKeyboard.shan" AND category == "memory"' --level info
```

`footprint + available` approximates the cap on that device and OS.

## Rebuilding the data files

Run after editing either JSON source, and commit the `.bin` output:

```
Scripts/convert_resources.sh
```
