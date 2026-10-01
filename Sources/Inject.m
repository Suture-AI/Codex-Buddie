#import "BuddieView.h"
#import <objc/runtime.h>

@interface NSWindow (Buddie)
- (void)buddie_setContentView:(NSView *)view;
- (void)buddie_orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)other;
@end
@implementation NSWindow (Buddie)
- (void)buddie_setContentView:(NSView *)view {
    [self buddie_setContentView:view];
    BuddieReplaceContent(self, view);
}
- (void)buddie_orderWindow:(NSWindowOrderingMode)place relativeTo:(NSInteger)other {
    if (place != NSWindowOut) BuddieReplaceContent(self, self.contentView);
    [self buddie_orderWindow:place relativeTo:other];
}
@end

__attribute__((constructor)) static void LoadBuddie(void) {
    @autoreleasepool {
        // Only loaded in a prepared copy or our explicit test harness.
        NSString *bundle = NSBundle.mainBundle.bundleIdentifier;
        if (![bundle isEqualToString:@"com.openai.sky.CUAService"] &&
            ![bundle isEqualToString:@"ai.suture.codex-buddie.runtime"] &&
            ![bundle isEqualToString:@"ai.suture.codex-buddie.preview"]) return;
        method_exchangeImplementations(class_getInstanceMethod(NSWindow.class, @selector(setContentView:)),
                                       class_getInstanceMethod(NSWindow.class, @selector(buddie_setContentView:)));
        method_exchangeImplementations(class_getInstanceMethod(NSWindow.class, @selector(orderWindow:relativeTo:)),
                                       class_getInstanceMethod(NSWindow.class, @selector(buddie_orderWindow:relativeTo:)));
        fprintf(stderr, "[Buddie] Native cursor renderer shim loaded.\n");
    }
}
