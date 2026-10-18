// Stand-in for the Swift code Xcode generates from
// LiveContainerSwiftUI/ViewApp.intentdefinition. That generator (intentbuilderc)
// only exists on macOS, so the Linux build compiles this file into
// LiveContainerSwiftUI instead. It declares just what AppDelegate.swift uses.
import Foundation
import Intents

@objc(App)
public class App: INObject {}

@objc(ViewAppIntent)
public class ViewAppIntent: INIntent {
    @NSManaged public var app: App?
}

@objc(ViewAppIntentHandling)
public protocol ViewAppIntentHandling: NSObjectProtocol {
    @objc(provideAppOptionsCollectionForViewApp:withCompletion:)
    func provideAppOptionsCollection(for intent: ViewAppIntent, with completion: @escaping (INObjectCollection<App>?, Error?) -> Void)
}
