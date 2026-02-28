//
//  AppDelegate.swift
//  Resonance
//
//  Created by Sepehr on 10/12/2025.
//



import UIKit
import FirebaseCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Firebase
        FirebaseApp.configure()
        print("Firebase initialized")
        print("App did finish launching")
        
        return true
    }
}
