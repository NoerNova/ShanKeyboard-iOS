# Shan Language Keyboard Layout for iOS (Unicode)

This project builds upon the now-archived [PanglongKeyboard-iOS](https://github.com/NoerNova/PanglongKeyboard-iOS), aiming to make customizing the Shan language keyboard layout for iOS much easier—until native support by Apple becomes available.

<p align="center">
  <img style="border: gray 1px solid;" width="320px" src="https://github.com/user-attachments/assets/c423fcd6-bea4-4766-8470-ffbb57ea1026"></img>
  &nbsp;&nbsp;
  <img style="border: gray 1px solid;" width="320px" src="https://github.com/user-attachments/assets/693190bc-2dde-4841-ba7d-ac3fe31a5dcc"></img>
</p>

## Features

### Just Type
This project aims to replicate the native iOS keyboard layout experience for the Shan language. It prioritizes simplicity:
- **No fancy themes** (though they could be added later).
- **No cluttered settings buttons** (which can also be added later).
- **No privacy concerns** — no open access requested, no network usage — just type!

### Text Autocomplete
A multi-layered autocomplete system provides intelligent word suggestions using a **3-slot priority system**:

1. **Personal suggestions** — learned words based on user typing history
2. **Contextual suggestions** — context-aware next-word predictions powered by a pre-trained n-gram (trigram/bigram/unigram) language model
3. **Dictionary suggestions** — frequency-sorted word matches from a curated Shan word list

With fallbacks to:
- **Syllable suggestions** — when primary slots are unfilled
- **Spell correction** — edit-distance-based corrections when input is invalid
- **Character predictions** — next-character suggestions based on Shan grammar rules

All suggestions are validated through **ShanGrammarRules** to ensure grammatical correctness before display.

### Shan Grammar Rules
A centralized grammar validation engine (`ShanGrammarRules.swift`) that defines:
- Consonants, vowels, medials, tone marks, and final consonant rules
- Valid consonant cluster combinations (hor/lape clusters)
- Pair-level character validation (`canFollow`)
- Full string grammatical validation (`isGrammaticallyValid`)
- Word boundary detection and next-character prediction

### Tokenizer
A dictionary-based word segmentation engine using dynamic programming for optimal tokenization, with NSCache-based result caching for performance.

## Dependencies

### KeyboardKit
This project is based on [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit), which does not yet support the Shan locale. To address this, I created a custom fork: [KeyboardKit-ShanPatched](https://github.com/NoerNova/KeyboardKit). This fork adds locale information for Shan.

### ISEmojiView
Since the free version of KeyboardKit doesn't support an emoji keyboard, I integrated [ISEmojiView](https://github.com/isaced/ISEmojiView), a SwiftUI package, to serve as a wrapper for emoji input.

## Project Structure

```
ShanKeyboard-iOS/
├── ShanKeyboard/                    # Host app (SwiftUI)
│   ├── ShanKeyboard.swift           # App entry point
│   ├── HomeScreen.swift             # Main screen
│   ├── AddKeyboardScreen.swift      # Setup instructions
│   ├── LayoutSettings.swift         # Layout configuration
│   ├── AboutScreen.swift            # About page
│   └── Fonts/                       # Custom fonts (Shan.ttf)
│
├── Shan/                            # Keyboard extension target
│   ├── KeyboardViewController.swift # Main keyboard view controller
│   ├── Controller/
│   │   └── ShanKeyboardInputViewController.swift
│   ├── Action/
│   │   └── ActionHandlerProvider.swift
│   ├── Behavior/
│   │   └── BehaviorProvider.swift
│   ├── Callout/
│   │   └── CalloutProvider.swift
│   ├── Layout/                      # Keyboard layout (iPhone & iPad)
│   │   ├── LayoutServiceProvider.swift
│   │   ├── CustomIPhoneService.swift
│   │   ├── CustomIPadService.swift
│   │   ├── KeyboardInputSet.swift
│   │   └── Toolbar.swift
│   ├── Style/
│   │   └── StyleProvider.swift
│   └── Autocomplete/                # Autocomplete pipeline
│       ├── AutocompleteServiceProvider.swift  # Main orchestrator
│       ├── AutocompleteDataManager.swift      # User learning & context
│       ├── LanguageService.swift              # Shan language parsing
│       ├── ShanGrammarRules.swift             # Grammar validation
│       ├── SharedResources.swift              # Singleton resource manager
│       ├── Tokenizer/
│       │   └── Tokenizer.swift                # Word segmentation
│       ├── Suggestion/                        # Suggestion services
│       │   ├── WordCompletionService.swift
│       │   ├── ContextualSuggestionService.swift
│       │   ├── DictionaryService.swift
│       │   ├── NGramService.swift
│       │   ├── SpellCorrectionService.swift
│       │   ├── CharacterPredictionService.swift
│       │   └── TrieNode.swift
│       └── Resource/                          # Data files
│           ├── dictionary.txt
│           ├── filtered_frequency_data.json
│           ├── filtered_frequency_data.plist
│           ├── bigram_data.json
│           └── bigram_data.plist
│
├── Scripts/
│   └── convert_resources.sh         # JSON → binary plist converter
│
├── ShanKeyboardTests/               # Unit tests
└── ShanKeyboardUITests/             # UI tests
```

## Development

### Prerequisites
- Xcode (latest stable version)
- iOS Simulator or physical device

### Build & Run

```bash
# Build the keyboard extension
xcodebuild -scheme Shan -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Build the host app
xcodebuild -scheme ShanKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Or open `ShanKeyboard.xcodeproj` in Xcode and select the **Shan** scheme to build the keyboard extension, or the **ShanKeyboard** scheme for the host app.

### Resource Build Pipeline
A pre-build script (`Scripts/convert_resources.sh`) automatically converts JSON resource files to binary plist format for faster runtime parsing. This runs before the "Copy Bundle Resources" build phase. If you update `filtered_frequency_data.json` or `bigram_data.json`, the binary plist files will be regenerated on the next build.

### Testing on Device
1. Build and run the **ShanKeyboard** host app on a simulator or device.
2. Go to **Settings → General → Keyboard → Keyboards → Add New Keyboard**.
3. Select **ShanKeyboard — Shan**.
4. Switch to the Shan keyboard in any text input field.

### Data Sources
- **Word list & dictionary**: sourced from the [ShanNLP](https://github.com/NoerNova/ShanNLP) project
- **Word/syllable frequency data**: analyzed from the [shannews.org](https://shannews.org) domain dataset
- **N-gram language model**: pre-trained bigram/trigram model analyzed from the [shannews.org](https://shannews.org) domain dataset

## Privacy
- The keyboard does **not** request open access (`RequestsOpenAccess: false`)
- No network requests are made
- Sensitive text detection is enabled for passwords and credit card fields
- Privacy manifests (`PrivacyInfo.xcprivacy`) are included in both targets

## Download

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/th/app/shankeyboard/id6752576307)

The app is available on the [App Store](https://apps.apple.com/th/app/shankeyboard/id6752576307). Feel free to also use this project as a foundation for developing your own keyboard apps.

## Support Me

[![Sponsor on GitHub](https://gist.githubusercontent.com/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/github_sponsor.svg)](https://github.com/sponsors/NoerNova)

## Contact
Feel free to reach out if you have questions or if you want to contribute in any way:

* Website: [noernova.com](https://noernova.com)
* Twitter: [@noer_nova](https://twitter.com/noer_nova)
* E-mail: [norhsangpha@gmail.com](mailto:norhsangpha@gmail.com)

## LICENSE
MIT
