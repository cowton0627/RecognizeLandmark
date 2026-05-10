//
//  SceneDelegate.swift
//  RecognizeLandmark
//
//  Created by RecognizeLandmark contributors on 2024/9/27.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = makeRootController()
        self.window = window
        window.makeKeyAndVisible()
    }

    private func makeRootController() -> UIViewController {
        let cameraVC: UIViewController = {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateInitialViewController() ?? UIViewController()
            vc.tabBarItem = UITabBarItem(
                title: "相機",
                image: UIImage(systemName: "camera"),
                selectedImage: UIImage(systemName: "camera.fill")
            )
            return vc
        }()

        let listVC: UIViewController = {
            let view = RecordsListView()
                .modelContainer(Persistence.container)
            let vc = UIHostingController(rootView: view)
            vc.tabBarItem = UITabBarItem(
                title: "記錄",
                image: UIImage(systemName: "list.bullet.rectangle"),
                selectedImage: UIImage(systemName: "list.bullet.rectangle.fill")
            )
            return vc
        }()

        let tabBar = UITabBarController()
        tabBar.viewControllers = [cameraVC, listVC]
        return tabBar
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
