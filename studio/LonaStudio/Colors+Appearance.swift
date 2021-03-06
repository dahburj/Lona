//
//  Colors+Appearance.swift
//  LonaStudio
//
//  Created by Devin Abbott on 1/3/19.
//  Copyright © 2019 Devin Abbott. All rights reserved.
//

import AppKit

extension Colors {
    public static let textColor: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: "textColor")!
        } else {
            return NSColor.black
        }
    }()

    public static let labelText: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: "labelTextColor")!
        } else {
            return NSColor.parse(css: "#545454")!
        }
    }()

    public static let headerBackground: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: "headerBackgroundColor")!
        } else {
            return NSColor.white
        }
    }()

    public static let contentHeaderBackground: NSColor = {
        if #available(OSX 10.14, *) {
            switch NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .some(.darkAqua):
                return NSColor.controlBackgroundColor
            default:
                return NSColor.white
            }
        } else {
            return NSColor.white
        }
    }()

    public static let contentBackground: NSColor = {
        if #available(OSX 10.14, *) {
            switch NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .some(.darkAqua):
                return NSColor.controlBackgroundColor
            default:
                return NSColor.white
            }
        } else {
            return NSColor.white
        }
    }()

    public static let dividerSubtle: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: "dividerSubtleColor")!
        } else {
            return NSColor.white
        }
    }()

    public static let divider: NSColor = {
        if #available(OSX 10.13, *) {
            return NSColor(named: "dividerColor")!
        } else {
            return NSColor.parse(css: "rgba(0,0,0,0.16)")!
        }
    }()
}
