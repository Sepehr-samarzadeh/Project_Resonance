import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        // Push notification setup
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        requestNotificationPermission(application: application)
        
        return true
    }
    
    private func requestNotificationPermission(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
    }
    
    // MARK: - APNs Token Registration
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Forward the APNs token to FCM
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    /// Handle foreground notifications — show them even when the app is active
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        // You can route to a specific view based on userInfo keys
        print("Notification tapped with info: \(userInfo)")
        completionHandler()
    }
}

// MARK: - MessagingDelegate (FCM)

extension AppDelegate: MessagingDelegate {
    
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM token: \(token)")
        
        // Save the FCM token to Firestore for the current user
        Task { @MainActor in
            if let userId = UserManager.shared.getCurrentUserId() {
                UserManager.shared.updateFCMToken(userId: userId, token: token)
            }
        }
    }
}
