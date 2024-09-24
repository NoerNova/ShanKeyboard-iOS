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
            case "1": return "1႑".chars.map { KeyboardAction.character($0)}
            case "2": return "2႒".chars.map { KeyboardAction.character($0)}
            case "3": return "3႓".chars.map { KeyboardAction.character($0)}
            case "4": return "4႔".chars.map { KeyboardAction.character($0)}
            case "5": return "5႕".chars.map { KeyboardAction.character($0)}
            case "6": return "6႖".chars.map { KeyboardAction.character($0)}
            case "7": return "7႗".chars.map { KeyboardAction.character($0)}
            case "8": return "8႘".chars.map { KeyboardAction.character($0)}
            case "9": return "9႙".chars.map { KeyboardAction.character($0)}
            case "0": return "0႐°".chars.map { KeyboardAction.character($0)}
            default: break
            }
        default: break
        }
        return super.calloutActions(for: action)
    }

}

//["႑", "႒", "႓", "႔", "႕", "႖", "႗", "႘", "႙", "႐"]
