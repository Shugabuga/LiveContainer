@import UIKit;

NS_ASSUME_NONNULL_BEGIN

// The Home button window's root view controller. It keeps the button against
// an edge of the screen, lets it be dragged or flung to another place like
// AssistiveTouch, dims it after a few seconds without a touch, and leaves
// rotation, the status bar, the Home indicator and the screen edge gestures to
// the app underneath.
@interface LCHomeButtonViewController : UIViewController

// Called when the button is pressed.
@property (nonatomic, copy, nullable) void (^pressHandler)(void);

// Covers the app in black, as it closes to go back to zContainer, and calls
// `completion` once the screen is black.
- (void)fadeOutWithCompletion:(void (^)(void))completion;

// Takes the black cover away again, when zContainer didn't open after all.
- (void)fadeBackIn;

@end

NS_ASSUME_NONNULL_END
