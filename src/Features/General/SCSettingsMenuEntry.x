#import "../../InstagramHeaders.h"
#import "../../Settings/SCISettingsViewController.h"
#import <objc/runtime.h>

static char SCIWindowSettingsGestureKey;

// Show SCInsta tweak settings by holding on the settings/more icon under profile for ~1 second
%hook IGBadgedNavigationButton
- (void)didMoveToWindow {
    %orig;

    if ([self.accessibilityIdentifier isEqualToString:@"profile-more-button"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}

%new - (void)addLongPressGestureRecognizer {
    if ([self.gestureRecognizers count] == 0) {
        NSLog(@"[SCInsta] Adding tweak settings long press gesture recognizer");

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:longPress];
    }
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    
    NSLog(@"[SCInsta] Tweak settings gesture activated");

    [SCIUtils showSettingsVC:[self window]];
}
%end

// Quick access to tweak settings by holding on home tab button
%hook IGTabBarButton
- (void)didMoveToSuperview {
    %orig;

    // Only work on home/feed tab
    if (![self.accessibilityIdentifier isEqualToString:@"mainfeed-tab"]) return;
    
    if ([SCIUtils getBoolPref:@"settings_shortcut"]) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 0.3;
        
        // Take precidence over existing gesture recognizers
        for (UIGestureRecognizer *existing in self.gestureRecognizers) {
            [existing requireGestureRecognizerToFail:longPress];
        }
        
        [self addGestureRecognizer:longPress];
    }
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    [SCIUtils showSettingsVC:[self window]];
}
%end

// Public UIKit entry point, independent of Instagram's private button classes.
%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    if (self.windowLevel != UIWindowLevelNormal || objc_getAssociatedObject(self, &SCIWindowSettingsGestureKey)) return;

    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sci_openSettingsFromWindow:)];
    gesture.numberOfTouchesRequired = 2;
    gesture.minimumPressDuration = 1.0;
    gesture.cancelsTouchesInView = NO;
    objc_setAssociatedObject(self, &SCIWindowSettingsGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addGestureRecognizer:gesture];
}

%new - (void)sci_openSettingsFromWindow:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    [SCIUtils showSettingsVC:self];
}
%end
