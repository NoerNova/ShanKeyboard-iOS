# Shan Language Keyboard Layout for iOS (Unicode)

This project builds upon the now-archived [PanglongKeyboard-iOS](https://github.com/NoerNova/PanglongKeyboard-iOS), aiming to make customizing the Shan language keyboard layout for iOS much easier—until native support by Apple becomes available.

<p align="center">
  <img style="border: gray 1px solid;" width="320px" src="https://github.com/user-attachments/assets/c423fcd6-bea4-4766-8470-ffbb57ea1026"></img>
  &nbsp;&nbsp;
  <img style="border: gray 1px solid;" width="320px" src="https://github.com/user-attachments/assets/693190bc-2dde-4841-ba7d-ac3fe31a5dcc"></img>
</p>

### Just Type
This project aims to replicate the native iOS keyboard layout experience for the Shan language. It prioritizes simplicity:
- **No fancy themes** (though they could be added later).
- **No cluttered settings buttons** (which can also be added later).
- **No privacy concerns**—just type!

### KeyboardKit
This project is based on [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit), which does not yet support the Shan locale. To address this, I created a custom fork: [KeyboardKit-ShanPatched](https://github.com/NoerNova/KeyboardKit). This fork adds some locale information for Shan, although it is not perfect yet. I hope to submit a pull request to the main repository soon.

### ISEmojiView
Since the free version of KeyboardKit doesn't support an emoji keyboard, I integrated [ISEmojiView](https://github.com/isaced/ISEmojiView), a SwiftUI package, to serve as a wrapper for emoji input. It works as intended.

### Text AutoComplete
This project also implements a basic text autocomplete feature, using the word list from the [ShanNLP](https://github.com/NoerNova/ShanNLP) project. The word list isn't fully optimized for daily typing yet, but I hope to expand it when I have more time and energy.

## Publishing Plans
I don't plan to publish this app on the App Store anytime soon. However, if anyone is interested, feel free to help with that or use this project as a foundation for developing production apps.

## Support Me

[![Sponsor on GitHub](https://gist.githubusercontent.com/cxmeel/0dbc95191f239b631c3874f4ccf114e2/raw/github_sponsor.svg)](https://github.com/sponsors/NoerNova)

## Contact
Feel free to reach out if you have questions or if you want to contribute in any way:

* Website: [noernova.com](https://noernova.com)
* Twitter: [@noer_nova](https://twitter.com/noer_nova)
* E-mail: [norhsangpha@gmail.com](mailto:norhsangpha@gmail)

## LICENSE
MIT
