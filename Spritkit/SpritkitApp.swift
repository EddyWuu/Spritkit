//
//  SpritkitApp.swift
//  Spritkit
//
//  Created by Edmond Wu on 2026-04-04.
//

import SwiftUI
import UIKit

@main
struct SpritkitApp: App {
    
    init() {
        Self.configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
    
    // Apply the pixel-art toolbox theme to UIKit-backed bars.
    private static func configureAppearance() {
        let ink = UIColor(Theme.ink)
        let steel = UIColor(Theme.steelDark)
        
        // Tab bar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = ink
        tab.shadowColor = steel
        
        let item = tab.stackedLayoutAppearance
        item.selected.iconColor = UIColor(Theme.accent)
        item.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.accent),
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .heavy)
        ]
        item.normal.iconColor = UIColor(Theme.steel)
        item.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.steel),
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        ]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        
        // Navigation bar
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = ink
        nav.shadowColor = steel
        let titleColor = UIColor(Theme.onDark)
        nav.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .heavy)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.monospacedSystemFont(ofSize: 30, weight: .heavy)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
