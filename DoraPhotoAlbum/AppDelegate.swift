//
//  AppDelegate.swift
//  DoraPhotoAlbum
//
//  Created by TigerSecurity on 2025/12/19.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Prevent screen from dimming/locking (photo frame style)
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Configure audio session (allow mixing with other audio)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        
        // Setup window (we don't use SceneDelegate; support iOS12+)
        window = UIWindow(frame: UIScreen.main.bounds)
        let mainVC = MainViewController()
        window?.rootViewController = mainVC
        window?.makeKeyAndVisible()
        return true
    }


}

