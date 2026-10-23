#import "LCHomeButtonController.h"
#import "LCAppDeparture.h"
#import "LCHomeButtonViewController.h"
#import "LCHomeButtonWindow.h"
#import "LCSharedUtils.h"
#import "../../LiveContainer/utils.h"

// How long the app gets to finish what it does on entering the background,
// such as saving, before zContainer opens and the app's process ends.
static const NSTimeInterval LCHomeButtonSaveTime = 0.3;
// How long to wait for zContainer to open before giving the app back.
static const NSTimeInterval LCHomeButtonLeaveTimeout = 4;

@interface LCHomeButtonController ()
@property (nonatomic, nullable) LCHomeButtonWindow *window;
@property (nonatomic, nullable) LCHomeButtonViewController *buttonController;
@property (nonatomic) LCAppDeparture *departure;
@property (nonatomic) BOOL isLeaving;
@end

@implementation LCHomeButtonController

+ (LCHomeButtonController *)sharedController {
    static LCHomeButtonController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        controller = [[LCHomeButtonController alloc] init];
    });
    return controller;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _departure = [[LCAppDeparture alloc] init];
    }
    return self;
}

- (void)start {
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(sceneDidActivate:) name:UISceneDidActivateNotification object:nil];
    [center addObserver:self selector:@selector(windowDidBecomeVisible:) name:UIWindowDidBecomeVisibleNotification object:nil];
}

// The button moves to the screen the person is using.
- (void)sceneDidActivate:(NSNotification *)notification {
    if ([notification.object isKindOfClass:UIWindowScene.class]) {
        [self showSoonInScene:notification.object];
    }
}

// Screens often come up before the app has put its window on them, so the
// button waits for the app's first window before it shows.
- (void)windowDidBecomeVisible:(NSNotification *)notification {
    UIWindow *window = notification.object;
    if (![window isKindOfClass:UIWindow.class] || window == self.window || self.window.windowScene) {
        return;
    }
    UIWindowScene *scene = window.windowScene;
    if (scene && (scene.activationState == UISceneActivationStateForegroundActive ||
                  scene.activationState == UISceneActivationStateForegroundInactive)) {
        [self showSoonInScene:scene];
    }
}

// Shows the button once the app is done with the change it is making to its
// windows, rather than in the middle of it.
- (void)showSoonInScene:(UIWindowScene *)scene {
    __weak LCHomeButtonController *weakSelf = self;
    __weak UIWindowScene *weakScene = scene;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *laterScene = weakScene;
        if (laterScene) {
            [weakSelf showInScene:laterScene];
        }
    });
}

// Whether the app has put a window with content on the screen. The button's
// window takes its orientation and status bar from that window. The windows
// UIKit keeps for the keyboard sit far above the app's and don't count.
- (BOOL)appHasWindowInScene:(UIWindowScene *)scene {
    for (UIWindow *window in scene.windows) {
        if (window != self.window && !window.hidden && window.rootViewController &&
            window.windowLevel < UIWindowLevelStatusBar) {
            return YES;
        }
    }
    return NO;
}

- (void)showInScene:(UIWindowScene *)scene {
    @try {
        if (self.window.windowScene == scene || ![self appHasWindowInScene:scene]) {
            return;
        }
        if (self.window) {
            self.window.windowScene = scene;
            self.window.hidden = NO;
            return;
        }

        LCHomeButtonViewController *buttonController = [[LCHomeButtonViewController alloc] init];
        __weak LCHomeButtonController *weakSelf = self;
        buttonController.pressHandler = ^{
            [weakSelf goBackToZContainer];
        };
        LCHomeButtonWindow *window = [[LCHomeButtonWindow alloc] initWithWindowScene:scene];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = UIColor.clearColor;
        window.rootViewController = buttonController;
        self.buttonController = buttonController;
        self.window = window;
        window.hidden = NO;
    } @catch (NSException *exception) {
        NSLog(@"[LC] The Home button couldn't show: %@", exception);
    }
}

// Opens zContainer again with no app chosen, after covering the app in black
// and telling it that it is going to the background, as pressing Home would,
// so it can save. zContainer's launch ends this process as soon as iOS has
// zContainer open; if it's still here a few seconds later, opening didn't
// work, so the app comes back to the foreground.
- (void)goBackToZContainer {
    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    if (self.isLeaving || ![sharedUtils respondsToSelector:@selector(launchToGuestAppWithClassicMode:)]) {
        return;
    }
    self.isLeaving = YES;
    __weak LCHomeButtonController *weakSelf = self;
    [self.buttonController fadeOutWithCompletion:^{
        NSUserDefaults *defaults = NSUserDefaults.lcUserDefaults;
        [defaults removeObjectForKey:@"selected"];
        [defaults removeObjectForKey:@"selectedContainer"];
        [defaults synchronize];
        [weakSelf.departure leave];
        // The app's background work runs on the main queue too, so it gets a
        // turn before zContainer opens.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonSaveTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf openZContainerWith:sharedUtils];
        });
    }];
}

- (void)openZContainerWith:(Class)sharedUtils {
    @try {
        [sharedUtils launchToGuestAppWithClassicMode:0];
    } @catch (NSException *exception) {
        NSLog(@"[LC] zContainer couldn't open: %@", exception);
    }
    __weak LCHomeButtonController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonLeaveTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LCHomeButtonController *controller = weakSelf;
        controller.isLeaving = NO;
        [controller.departure comeBack];
        [controller.buttonController fadeBackIn];
    });
}

@end

// Shows the Home button in apps zContainer runs itself, once Settings > Home
// Screen turns it on for apps, which it isn't until then, unless the app's
// settings turn it off. TweakLoader also loads into zContainer's own screens
// when tweaks are set to load there, which have no app chosen and keep their
// own Home button.
__attribute__((constructor))
static void LCHomeButtonInit(void) {
    if (!NSUserDefaults.lcGuestAppId || NSUserDefaults.isLiveProcess) {
        return;
    }
    if (![NSUserDefaults.lcUserDefaults boolForKey:@"LCShowHomeButtonInApps"]) {
        return;
    }
    if ([NSUserDefaults.guestAppInfo[@"hideHomeButton"] boolValue]) {
        return;
    }
    [LCHomeButtonController.sharedController start];
}
