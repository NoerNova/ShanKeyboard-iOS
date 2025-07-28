//
//  CalloutProvider.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 22/9/2567 BE.
//

import KeyboardKit

class CalloutProvider: Callouts.BaseService {
    
    override func calloutActions(for action: KeyboardAction) -> [KeyboardAction] {
        switch action {
        case .character(let char):
            switch char {
            case "1": return "1၁႑".chars.map { KeyboardAction.character($0)}
            case "2": return "2၂႒".chars.map { KeyboardAction.character($0)}
            case "3": return "3၃႓".chars.map { KeyboardAction.character($0)}
            case "4": return "4၄႔".chars.map { KeyboardAction.character($0)}
            case "5": return "5၅႕".chars.map { KeyboardAction.character($0)}
            case "6": return "6၆႖".chars.map { KeyboardAction.character($0)}
            case "7": return "7၇႗".chars.map { KeyboardAction.character($0)}
            case "8": return "8၈႘".chars.map { KeyboardAction.character($0)}
            case "9": return "9၉႙".chars.map { KeyboardAction.character($0)}
            case "0": return "0၀႐°".chars.map { KeyboardAction.character($0)}
            case "ꩡ": return "ꩡၹ".chars.map { KeyboardAction.character($0)}
            case "ၻ": return "ၻꩦꩨ".chars.map { KeyboardAction.character($0)}
            case "သ": return "သႀ︀".chars.map { KeyboardAction.character($0)}
            case "ႅ": return ["ႅ", "ꧥ"].map { KeyboardAction.character($0)}
            case "ၾ": return "ၾꧤ".chars.map { KeyboardAction.character($0)}
            case "ꩪ": return "ꩪꩧ".chars.map { KeyboardAction.character($0)}
            case "။": return "။၊".chars.map { KeyboardAction.character($0)}
            default: break
            }
        default: break
        }
        return super.calloutActions(for: action)
    }

}

//["႑", "႒", "႓", "႔", "႕", "႖", "႗", "႘", "႙", "႐"]
