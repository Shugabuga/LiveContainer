#import "DecoratedAppSceneViewController.h"
#import "ResizeHandleView.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "AppSceneViewController.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import "PiPManager.h"
#import "VirtualWindowsHostView.h"
#import "../LiveContainer/Localization.h"
#import "utils.h"

/// A window's look, after iPadOS: continuous rounded corners and a soft
/// shadow in place of a border.
static const CGFloat LCWindowCornerRadius = 22.0;
/// A maximized window fills the screen edge to edge, so the screen's own
/// corners round it.
static const CGFloat LCMaximizedWindowCornerRadius = 0.0;
static const CGFloat LCWindowShadowOpacity = 0.28;
/// The close, minimize and maximize dots in the title bar's leading corner.
static const CGFloat LCWindowControlDiameter = 14.0;
/// Each dot's share of the row: close together, as on iPadOS, but the full
/// height of the title bar.
static const CGSize LCWindowControlSize = {26.0, 44.0};
/// How far beyond the row a touch still counts.
static const CGFloat LCWindowControlTouchSlop = 12.0;

/// A window's outer view. It doesn't clip, so its shadow can show; the title
/// bar and the app clip themselves to the corners instead
/// (`updateCornerMasks`). It keeps the shadow's path in step with its size,
/// so the shadow isn't worked out from the app's pixels on every frame.
@interface LCWindowView : UIStackView
@end

@implementation LCWindowView
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}
@end

/// The row of window controls. The dots are small and close together, so
/// the row takes any touch on or near it and gives it to the closest dot,
/// rather than leaving each its own small square.
@interface LCWindowControlsView : UIStackView
@end

@implementation LCWindowControlsView
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(CGRectInset(self.bounds, -LCWindowControlTouchSlop, -LCWindowControlTouchSlop), point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.01 || !self.userInteractionEnabled || ![self pointInside:point withEvent:event]) {
        return nil;
    }
    UIView *nearest = nil;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (UIView *control in self.arrangedSubviews) {
        CGFloat distance = hypot(point.x - control.center.x, point.y - control.center.y);
        if (distance < nearestDistance) {
            nearestDistance = distance;
            nearest = control;
        }
    }
    return nearest;
}
@end

@interface DecoratedAppSceneViewController()
@property(nonatomic) NSArray* activatedVerticalConstraints;
@property(nonatomic) NSString* dataUUID;
@property(nonatomic) int pid;
@property(nonatomic) CGRect originalFrame;
/// The green dots: the title bar's and the floating one's.
@property(nonatomic) NSMutableArray<UIButton *> *maximizeControls;
/// The window controls over the app's top-leading corner while the window
/// fills the screen and has no title bar. Hidden until asked for: by a tap
/// on the leading half of the status bar, or on the multitask dock
/// (`revealWindowControls`). Touches on the app itself go to its own scene,
/// so the window can't watch for a gesture there.
@property(nonatomic) UIView *floatingControls;
/// Counts reveals, so only the latest one's timer hides the controls.
@property(nonatomic) NSUInteger floatingControlsReveal;
@property(nonatomic) bool isAppTerminationRequested;
@end

@implementation DecoratedAppSceneViewController
- (instancetype)initWindowName:(NSString*)windowName bundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID rootVC:(UIViewController*)rootVC {
    self = [super initWithNibName:nil bundle:nil];
    self.view = [[LCWindowView alloc] initWithFrame:self.view.frame];
    [MultitaskDockManager.shared.windowHostingView addSubview:self.view];
    [rootVC addChildViewController:self];
    
    _dataUUID = dataUUID;
    _scaleRatio = 1.0;
    _isMaximized = [NSUserDefaults.lcUserDefaults boolForKey:@"LCLaunchMultitaskMaximized"];
    _appSceneVC = [[AppSceneViewController alloc] initWithBundleId:bundleId dataUUID:dataUUID delegate:self];
    self.title = windowName;
    [self setupDecoratedView];
    
    [MultitaskDockManager.shared addRunningApp:windowName appUUID:dataUUID view:self.view];
    
    NSArray *menuItems = @[
        [UIAction actionWithTitle:@"lc.multitask.copyPid".loc image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction * _Nonnull action) {
            UIPasteboard.generalPasteboard.string = @(self.appSceneVC.pid).stringValue;
        }],
        [UIAction actionWithTitle:@"lc.multitask.enablePip".loc image:[UIImage systemImageNamed:@"pip.enter"] identifier:nil handler:^(UIAction * _Nonnull action) {
            if ([PiPManager.shared isPiPWithVC:self.appSceneVC]) {
                [PiPManager.shared stopPiP];
            } else {
                [PiPManager.shared startPiPWithVC:self.appSceneVC];
            }
        }],
        [UICustomViewMenuElement elementWithViewProvider:^UIView *(UICustomViewMenuElement *element) {
            return [self scaleSliderViewWithTitle:@"lc.multitask.scale".loc min:0.5 max:2.0 value:self.scaleRatio stepInterval:0.01];
        }]
    ];
    

    __weak typeof(self) weakSelf = self;
    [self.navigationItem setTitleMenuProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions){
        if(!weakSelf.appSceneVC.isAppRunning) {
            return [UIMenu menuWithTitle:NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", nil) children:@[]];
        } else {
            NSString *pidText = [NSString stringWithFormat:@"PID: %d", weakSelf.pid];
            return [UIMenu menuWithTitle:pidText children:menuItems];
        }
    }];
    
    // iPadOS's window controls: close, minimize and maximize as colored dots
    // in the leading corner, wherever the bar is. On their own, without the
    // glass capsule iOS 26 puts behind a navigation bar's items.
    UIBarButtonItem *controlsItem = [[UIBarButtonItem alloc] initWithCustomView:[self windowControlsView]];
    if (@available(iOS 26.0, *)) {
        controlsItem.hidesSharedBackground = YES;
    }
    self.navigationItem.leftBarButtonItem = controlsItem;

    return self;
}

- (void)setupDecoratedView {
    CGFloat navBarHeight = 44;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape(UIApp.statusBarOrientation);
    CGRect frame = CGRectMake(0, 0, isLandscape ? 480 : 320, (isLandscape ? 320 : 480) + navBarHeight);
    CGPoint rootViewCenter = self.view.superview.center;
    frame.origin = CGPointMake(rootViewCenter.x - frame.size.width / 2, rootViewCenter.y - frame.size.height / 2);
    
    if(_isMaximized) {
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        // save origin as normalized coordinates
        frame.origin.x /= maxFrame.size.width;
        frame.origin.y /= maxFrame.size.height;
        self.originalFrame = frame;
    } else {
        self.view.frame = frame;
    }
    
    // Navigation bar
    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, navBarHeight)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:self.title];
    navigationBar.items = @[navigationItem];
    // A quiet title bar, as on iPadOS: material, no hairline, a smaller title.
    UINavigationBarAppearance *barAppearance = [UINavigationBarAppearance new];
    [barAppearance configureWithDefaultBackground];
    barAppearance.backgroundEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    barAppearance.shadowColor = nil;
    barAppearance.titleTextAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold],
        NSForegroundColorAttributeName: UIColor.secondaryLabelColor,
    };
    navigationBar.standardAppearance = barAppearance;
    navigationBar.compactAppearance = barAppearance;
    navigationBar.scrollEdgeAppearance = barAppearance;
    
    self.view.axis = UILayoutConstraintAxisVertical;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.layer.cornerCurve = kCACornerCurveContinuous;
    self.view.layer.masksToBounds = NO;
    self.view.layer.shadowColor = UIColor.blackColor.CGColor;
    self.view.layer.shadowOffset = CGSizeMake(0, 8);
    self.view.layer.shadowRadius = 24;

    self.navigationBar = navigationBar;
    self.navigationItem = navigationBar.items.firstObject;
    if (!self.navigationBar.superview) {
        [self.view addArrangedSubview:self.navigationBar];
    }
    
    CGRect contentFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - navBarHeight);
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if([NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"]) {
        [self.view insertArrangedSubview:fixedPositionContentView atIndex:0];
    } else {
        [self.view addArrangedSubview:fixedPositionContentView];
    }
    [self.view sendSubviewToBack:fixedPositionContentView];
    
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.anchorPoint = self.contentView.layer.position = CGPointMake(0, 0);
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [fixedPositionContentView addSubview:self.contentView];
    
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [self.navigationBar addGestureRecognizer:moveGesture];

    // Resize handle (idea stolen from Notes debugging window)
    UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - navBarHeight, self.view.frame.size.height - navBarHeight, navBarHeight, navBarHeight)];
    self.resizeHandle.alpha = _isMaximized ? 0.0 : 1.0;
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.view addSubview:self.resizeHandle];
    
    [self addChildViewController:_appSceneVC];
    [self.view insertSubview:_appSceneVC.view atIndex:0];

    self.floatingControls = [self windowControlsView];
    self.floatingControls.translatesAutoresizingMaskIntoConstraints = NO;
    self.floatingControls.alpha = 0;
    self.floatingControls.hidden = YES;
    // A shadow keeps the dots readable over whatever the app draws there.
    self.floatingControls.layer.shadowColor = UIColor.blackColor.CGColor;
    self.floatingControls.layer.shadowOpacity = 0.3;
    self.floatingControls.layer.shadowRadius = 3;
    self.floatingControls.layer.shadowOffset = CGSizeZero;
    [self.view addSubview:self.floatingControls];
    [NSLayoutConstraint activateConstraints:@[
        [self.floatingControls.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:6],
        [self.floatingControls.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-4],
    ]];

    [self applyWindowStyleMaximized:_isMaximized];
    _appSceneVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self updateVerticalConstraints];
    [NSLayoutConstraint activateConstraints:@[
        [_appSceneVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_appSceneVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    
    NSUserDefaults *defaults = NSUserDefaults.lcSharedDefaults;

    [defaults addObserver:self forKeyPath:@"LCMultitaskBottomWindowBar" options:NSKeyValueObservingOptionNew context:NULL];
    [self updateOriginalFrame];
}


// Stolen from UIKitester
- (UIView *)scaleSliderViewWithTitle:(NSString *)title min:(CGFloat)minValue max:(CGFloat)maxValue value:(CGFloat)initialValue stepInterval:(CGFloat)step {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.exclusiveTouch = YES;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 0.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:10.0],
        [stackView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8.0],
        [stackView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16.0],
        [stackView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16.0]
    ]];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont boldSystemFontOfSize:12.0];
    [stackView addArrangedSubview:label];
    
    _UIPrototypingMenuSlider *slider = [[_UIPrototypingMenuSlider alloc] init];
    slider.minimumValue = minValue;
    slider.maximumValue = maxValue;
    slider.value = initialValue;
    slider.stepSize = step;
    
    NSLayoutConstraint *sliderHeight = [slider.heightAnchor constraintEqualToConstant:40.0];
    sliderHeight.active = YES;
    
    [stackView addArrangedSubview:slider];
    
    [slider addTarget:self action:@selector(scaleSliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    return containerView;
}

- (void)scaleSliderChanged:(_UIPrototypingMenuSlider *)slider {
    self.scaleRatio = slider.value;
    self.appSceneVC.scaleRatio = _scaleRatio;
    if(self.appSceneVC.usesHostingControllerAPI) {
        self.appSceneVC.contentView.transform = CGAffineTransformMakeScale(_scaleRatio, _scaleRatio);
    } else {
        self.appSceneVC.contentView.layer.sublayerTransform = CATransform3DMakeScale(_scaleRatio, _scaleRatio, 1.0);
    }
    __weak typeof(self) weakSelf = self;
    [self.appSceneVC updateFrameWithSettingsBlock:^(UIMutableApplicationSceneSettings *settings) {
        if(weakSelf.isMaximized) {
            [weakSelf updateMaximizedSafeAreaWithSettings:settings];
        } else {
            // it seems some apps don't honor these settings so we don't cover the top of the app
            settings.peripheryInsets = UIEdgeInsetsZero;
            settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
        }
    }];
}

- (void)closeWindow {
    _isAppTerminationRequested = true;
    if([_appSceneVC isAppRunning]) {
        [_appSceneVC terminate];
    } else {
        [self appSceneVCAppDidExit:self.appSceneVC];
    }
}

- (void)minimizeWindow {
    if (self.view.hidden) return;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
        self.view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        // An interrupted minimize used to stop here and leave the window
        // invisible but not hidden, still taking touches. Only bringing the
        // window back (which fades it in again) should cancel it.
        if (!finished && self.view.alpha > 0) return;
        self.view.hidden = YES;
        self.view.transform = CGAffineTransformIdentity;
        [self.view.superview sendSubviewToBack:self.view];
    }];
}

- (void)minimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL finished) {
        self.view.hidden = YES;
    }];
}

- (void)unminimizeWindowPiP {
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.view.hidden = NO;
        self.view.alpha = 1;
    } completion:nil];
}

- (void)maximizeWindow {
    void (^updateSettingsBlock)(UIMutableApplicationSceneSettings *settings);
    
    [self.view layoutIfNeeded];
    if (self.isMaximized) {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateWindowedFrameWithSettings:settings];
        };
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
        // The title bar comes back as the window shrinks, not after.
        self.isMaximized = NO;
        [self updateVerticalConstraints];
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            [self applyWindowStyleMaximized:NO];
            self.resizeHandle.alpha = 1;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self updateMaximizeControl];
        }];
    } else {
        updateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings) {
            [self updateMaximizedFrameWithSettings:settings];
        };
        [self updateOriginalFrame];
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.isMaximized = YES;
            [self updateVerticalConstraints];
            
            [self applyWindowStyleMaximized:YES];
            self.resizeHandle.alpha = 0;
            
            [self.appSceneVC updateSettingsWithBlock:updateSettingsBlock];
            
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            [self updateMaximizeControl];
        }];
    }
}

- (void)appSceneVCAppDidExit:(AppSceneViewController*)vc {
    BOOL skipTerminationScreen = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCSkipTerminatedScreen"];
    BOOL isManual = _isAppTerminationRequested;
    if(isManual || skipTerminationScreen) {
        
        MultitaskDockManager *dock = [MultitaskDockManager shared];
        [dock removeRunningApp:self.dataUUID];
        
        // Closing shrinks and fades the window away, as iPadOS does.
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.view.transform = CGAffineTransformMakeScale(0.85, 0.85);
            self.view.alpha = 0;
        } completion:^(BOOL b){
            [self.view removeFromSuperview];
        }];
        
        if(skipTerminationScreen) {
            [MultitaskRelaunchManager scheduleRelaunchIfNeededWithBundleId:self.appSceneVC.bundleId dataUUID:self.dataUUID isManualTermination:isManual];
        }
    } else {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        label.numberOfLines = 0;
        label.text = NSLocalizedString(@"lc.multitaskAppWindow.appTerminated", @"");
        label.textAlignment = NSTextAlignmentCenter;
        [self.view insertSubview:label atIndex:0];
    }
}

- (void)appSceneVC:(AppSceneViewController*)vc didInitializeWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(error) {
            [vc appTerminationCleanUp];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"lc.common.error".loc message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.ok".loc style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.copy".loc style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = error.localizedDescription;
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            self.pid = vc.pid;
            [self updateOriginalFrame];
            if (self.pidAvailableHandler) {
                self.pidAvailableHandler(@(self.pid), nil);
            }
        }
    });
}

- (void)appSceneVCWillActivateScene:(AppSceneViewController *)vc {
    // Set up initial settings such as frame, safe area, etc
    [self appSceneVC:vc didUpdateFromSettings:vc.presenter.scene.settings.mutableCopy transitionContext:nil lifecycleActionType:0];
}

- (void)appSceneVC:(AppSceneViewController*)vc didUpdateFromSettings:(UIMutableApplicationSceneSettings *)baseSettings transitionContext:(id)newContext lifecycleActionType:(uint32_t)actionType {
    [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.userInterfaceStyle = baseSettings.userInterfaceStyle;
        settings.interfaceOrientation = baseSettings.interfaceOrientation;
        settings.deviceOrientation = baseSettings.deviceOrientation;
        settings.foreground = YES;
        
        if(self.isMaximized) {
            [self updateMaximizedFrameWithSettings:settings];
        } else {
            [self updateWindowedFrameWithSettings:settings];
        }
        CGRect newFrame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - self.navigationBar.frame.size.height/self.scaleRatio);
        
        if(UIInterfaceOrientationIsLandscape(baseSettings.interfaceOrientation)) {
            settings.frame = CGRectMake(0, 0, newFrame.size.height, newFrame.size.width);
        } else {
            settings.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [change[NSKeyValueChangeNewKey] boolValue];
        // The window controls stay in the leading corner either way.
        if(bottomWindowBar) {
            [self.view addArrangedSubview:self.navigationBar];
        } else {
            [self.view insertArrangedSubview:self.navigationBar atIndex:0];
        }
        
        [self updateVerticalConstraints];
        
        if(_isMaximized) {
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [self updateMaximizedFrameWithSettings:settings];
            }];
        }
        [self.view layoutIfNeeded];
    }];
}

- (void)moveWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];

    self.view.center = CGPointMake(self.view.center.x + point.x, self.view.center.y + point.y);
    [self updateOriginalFrame];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];

    CGRect frame = self.view.frame;
    frame.size.width = MAX(50, frame.size.width + point.x);
    frame.size.height = MAX(50, frame.size.height + point.y);
    self.view.frame = frame;
    [self updateOriginalFrame];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    // FIXME: how to bring view to front when touching the passthrough view?
    // Reading the host view brings it back above the Home Screen first, in
    // case something the Home Screen drew since covered the windows.
    [MultitaskDockManager.shared windowHostingView];
    [self.view.superview bringSubviewToFront:self.view];
}

- (void)updateVerticalConstraints {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.3 animations:^{
        BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
        // Maximized is full screen, as on iPadOS: no title bar, the app edge
        // to edge with the screen's safe area passed on to it, and the
        // window controls floating over its top-leading corner.
        BOOL hideWindowBar = self.isMaximized;
        CGFloat navBarHeight = hideWindowBar ? 0 : 44;
        self.navigationBar.alpha = hideWindowBar ? 0 : 1;
        self.navigationBar.hidden = hideWindowBar;
        // The floating controls start hidden either way.
        [self.view bringSubviewToFront:self.floatingControls];
        self.floatingControlsReveal++;
        self.floatingControls.alpha = 0;
        self.floatingControls.hidden = YES;
        
        // Update safe area insets
        if(self.isMaximized) {
            self.appSceneVC.shouldSkipDebounceOnce = YES;
            __weak typeof(self) weakSelf = self;
            [self.appSceneVC updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                [weakSelf updateMaximizedFrameWithSettings:settings];
            }];
        }
        
        [NSLayoutConstraint deactivateConstraints:self.activatedVerticalConstraints];
        if(bottomWindowBar) {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-navBarHeight],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        } else {
            self.activatedVerticalConstraints = @[
                [self.appSceneVC.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:navBarHeight],
                [self.appSceneVC.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
                [self.navigationBar.heightAnchor constraintEqualToConstant:navBarHeight]
            ];
        }
        [NSLayoutConstraint activateConstraints:self.activatedVerticalConstraints];
        [self updateCornerMasks];

        [self.view layoutIfNeeded];
    }];
}

#pragma mark - Floating controls

/// Shows the floating window controls, then hides them again after
/// `duration` seconds, unless another reveal came in meanwhile.
- (void)revealFloatingControlsFor:(NSTimeInterval)duration {
    NSUInteger reveal = ++self.floatingControlsReveal;
    self.floatingControls.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        self.floatingControls.alpha = 1;
    }];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || reveal != self.floatingControlsReveal || !self.isMaximized) return;
        [UIView animateWithDuration:0.3 animations:^{
            self.floatingControls.alpha = 0;
        } completion:^(BOOL finished) {
            if (reveal == self.floatingControlsReveal && self.floatingControls.alpha == 0) {
                self.floatingControls.hidden = YES;
            }
        }];
    });
}

- (void)revealWindowControls {
    if (!self.isMaximized) return;
    [self revealFloatingControlsFor:4.0];
}

- (BOOL)revealWindowControlsForStatusBarTap:(UIAction *)action {
    if (!self.isMaximized) return NO;
    // UIStatusBarTapAction says where along the bar the tap was; a tap on
    // the leading half, the clock's, shows the controls, and one on the
    // other half still scrolls the app to the top. Without a position, any
    // tap shows them.
    SEL xPosition = NSSelectorFromString(@"xPosition");
    if ([action respondsToSelector:xPosition]) {
        CGFloat x = [[action valueForKey:@"xPosition"] doubleValue];
        CGFloat width = self.view.bounds.size.width;
        BOOL leading = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? x > width / 2 : x < width / 2;
        if (!leading) return NO;
    }
    [self revealFloatingControlsFor:4.0];
    return YES;
}

#pragma mark - Window style

/// Rounds the window's corners and gives it its shadow: smaller corners and
/// no shadow while it fills the screen, as an iPadOS window has.
- (void)applyWindowStyleMaximized:(BOOL)maximized {
    CGFloat radius = maximized ? LCMaximizedWindowCornerRadius : LCWindowCornerRadius;
    self.view.layer.cornerRadius = radius;
    self.view.layer.shadowOpacity = maximized ? 0 : LCWindowShadowOpacity;
    if ([self.resizeHandle isKindOfClass:ResizeHandleView.class]) {
        ((ResizeHandleView *)self.resizeHandle).windowCornerRadius = radius;
    }
    [self updateCornerMasks];
    [self.view setNeedsLayout];
}

/// Clips the title bar and the app to the window's rounded corners: the bar
/// takes the corners on its side, the app the others, or all four when the
/// bar is hidden. The window view itself can't clip, or it would cut off its
/// own shadow.
- (void)updateCornerMasks {
    CGFloat radius = self.view.layer.cornerRadius;
    CACornerMask top = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    CACornerMask bottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    CACornerMask barCorners = bottomWindowBar ? bottom : top;
    CACornerMask appCorners = self.navigationBar.hidden ? (top | bottom) : (bottomWindowBar ? top : bottom);
    for (UIView *view in @[self.navigationBar, self.appSceneVC.view]) {
        view.layer.cornerRadius = radius;
        view.layer.cornerCurve = kCACornerCurveContinuous;
        view.layer.masksToBounds = YES;
    }
    self.navigationBar.layer.maskedCorners = barCorners;
    self.appSceneVC.view.layer.maskedCorners = appCorners;
}

/// The close, minimize and maximize dots, in a row for the title bar.
- (UIView *)windowControlsView {
    UIButton *close = [self windowControlWithColor:UIColor.systemRedColor symbol:@"xmark" action:@selector(closeWindow)];
    close.accessibilityLabel = @"Close";
    UIButton *minimize = [self windowControlWithColor:UIColor.systemYellowColor symbol:@"minus" action:@selector(minimizeWindow)];
    minimize.accessibilityLabel = @"Minimize";
    UIButton *maximize = [self windowControlWithColor:UIColor.systemGreenColor symbol:nil action:@selector(maximizeWindow)];
    if (!self.maximizeControls) {
        self.maximizeControls = [NSMutableArray array];
    }
    [self.maximizeControls addObject:maximize];
    [self updateMaximizeControl];

    LCWindowControlsView *controls = [[LCWindowControlsView alloc] initWithArrangedSubviews:@[close, minimize, maximize]];
    controls.axis = UILayoutConstraintAxisHorizontal;
    controls.spacing = 0;
    controls.frame = CGRectMake(0, 0, LCWindowControlSize.width * 3, LCWindowControlSize.height);
    return controls;
}

/// One of the dots: a colored circle with a small dark glyph, in a touch
/// area larger than it.
- (UIButton *)windowControlWithColor:(UIColor *)color symbol:(NSString *)symbol action:(SEL)action {
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsZero;
    UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:nil];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.widthAnchor constraintEqualToConstant:LCWindowControlSize.width].active = YES;
    [button.heightAnchor constraintEqualToConstant:LCWindowControlSize.height].active = YES;

    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.userInteractionEnabled = NO;
    dot.backgroundColor = color;
    dot.layer.cornerRadius = LCWindowControlDiameter / 2;
    dot.tag = 1;
    [button addSubview:dot];

    UIImageView *glyph = [[UIImageView alloc] init];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.contentMode = UIViewContentModeCenter;
    glyph.tintColor = [UIColor colorWithWhite:0 alpha:0.55];
    glyph.tag = 2;
    [dot addSubview:glyph];
    [self setGlyph:symbol ofWindowControl:button];

    [NSLayoutConstraint activateConstraints:@[
        [dot.widthAnchor constraintEqualToConstant:LCWindowControlDiameter],
        [dot.heightAnchor constraintEqualToConstant:LCWindowControlDiameter],
        [dot.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [dot.centerYAnchor constraintEqualToAnchor:button.centerYAnchor],
        [glyph.centerXAnchor constraintEqualToAnchor:dot.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor],
    ]];
    return button;
}

- (void)setGlyph:(NSString *)symbol ofWindowControl:(UIButton *)button {
    UIImageView *glyph = (UIImageView *)[[button viewWithTag:1] viewWithTag:2];
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:7 weight:UIImageSymbolWeightBlack];
    glyph.image = symbol ? [[UIImage systemImageNamed:symbol] imageWithConfiguration:configuration] : nil;
}

/// The green dot's glyph and label follow whether the window fills the screen.
- (void)updateMaximizeControl {
    NSString *symbol = self.isMaximized ? @"arrow.down.right.and.arrow.up.left" : @"arrow.up.left.and.arrow.down.right";
    for (UIButton *control in self.maximizeControls) {
        [self setGlyph:symbol ofWindowControl:control];
        control.accessibilityLabel = self.isMaximized ? @"Exit Full Screen" : @"Full Screen";
    }
}

- (UIEdgeInsets)updateMaximizedSafeAreaWithSettings:(UIMutableApplicationSceneSettings *)settings {
    BOOL bottomWindowBar = [NSUserDefaults.lcSharedDefaults boolForKey:@"LCMultitaskBottomWindowBar"];
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    if(self.navigationBar.hidden) {
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets = UIEdgeInsetsZero;
    } else if(bottomWindowBar) {
        // allow the control bar to overlap the bottom safe area
        safeAreaInsets.bottom = 0;
        settings.peripheryInsets = safeAreaInsets;
        safeAreaInsets.top = safeAreaInsets.left = safeAreaInsets.right = 0;
    } else {
        settings.peripheryInsets = UIEdgeInsetsMake(0, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right);
        safeAreaInsets.bottom = safeAreaInsets.left = safeAreaInsets.right = 0;
    }
    
    // scale peripheryInsets to match the scale ratio
    settings.peripheryInsets = UIEdgeInsetsMake(settings.peripheryInsets.top/_scaleRatio, settings.peripheryInsets.left/_scaleRatio, settings.peripheryInsets.bottom/_scaleRatio, settings.peripheryInsets.right/_scaleRatio);
    if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        UIInterfaceOrientation currentOrientation = UIApp.statusBarOrientation;
        if(UIInterfaceOrientationIsLandscape(currentOrientation)) {
            safeAreaInsets.top = 0;
        }
        settings.safeAreaInsetsPortrait = LCUIEdgeInsetsRotateToOrientation(settings.peripheryInsets, currentOrientation);

    } else {
        settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.top, settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right);
    }
    
    safeAreaInsets.bottom = 0;
    return safeAreaInsets;
}

- (void)updateMaximizedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, [self updateMaximizedSafeAreaWithSettings:settings]);
    self.view.frame = maxFrame;
}

- (void)updateWindowedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, safeAreaInsets);
    settings.peripheryInsets = UIEdgeInsetsZero;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
    
    CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
    CGPoint center = self.view.center;
    CGRect frame = CGRectZero;
    frame.size.width = MIN(newFrame.size.width, maxFrame.size.width);
    frame.size.height = MIN(newFrame.size.height, maxFrame.size.height);
    CGFloat oobOffset = MAX(30, frame.size.width - 30);
    frame.origin.x = MAX(maxFrame.origin.x - oobOffset, MIN(CGRectGetMaxX(maxFrame) - frame.size.width + oobOffset, center.x - frame.size.width / 2));
    frame.origin.y = MAX(maxFrame.origin.y, MIN(center.y - frame.size.height / 2, CGRectGetMaxY(maxFrame) - frame.size.height));
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = frame;
    }];
}

- (void)updateOriginalFrame {
    if(_isMaximized) return;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
    // save origin as normalized coordinates
    self.originalFrame = CGRectMake(self.view.frame.origin.x / maxFrame.size.width, self.view.frame.origin.y / maxFrame.size.height, self.view.frame.size.width, self.view.frame.size.height);
}

@end
