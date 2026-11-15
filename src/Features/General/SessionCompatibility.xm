/*
 * Instagram sideload compatibility. Based on opa334/IGSideloadFix and the
 * receipt handling in Mihir-A/Unscroll (01c5ed9b0678ae233dcdc81033e4500e6eac30e6).
 * Copyright (c) 2022 Lars Fröder. MIT license: licenses/IGSideloadFix-MIT.txt.
 */
#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Discover the group permitted by the current signature without reading tokens.
static NSString *SCIAvailableKeychainAccessGroup(void) {
    static NSString *availableGroup;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *query = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrAccount: @"SCInstaAccessGroupProbe",
            (__bridge id)kSecAttrService: @"com.danzola.scinsta.compatibility",
            (__bridge id)kSecReturnAttributes: @YES
        };
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        if (status == errSecItemNotFound) {
            status = SecItemAdd((__bridge CFDictionaryRef)query, &result);
        }
        if (status == errSecSuccess && result != NULL) {
            NSDictionary *attributes = CFBridgingRelease(result);
            id group = attributes[(__bridge id)kSecAttrAccessGroup];
            if ([group isKindOfClass:[NSString class]] && [group length] > 0) {
                availableGroup = group;
            }
        } else if (result != NULL) {
            CFRelease(result);
        }
    });
    return availableGroup;
}

// Instagram's wrappers also consult their access group before reaching SecItem*.
%hook FBSDKKeychainStore
- (NSString *)accessGroup {
    NSString *group = SCIAvailableKeychainAccessGroup();
    if (group.length > 0) return group;
    return %orig;
}
%end

%hook FBKeychainItemController
- (NSString *)accessGroup {
    NSString *group = SCIAvailableKeychainAccessGroup();
    if (group.length > 0) return group;
    return %orig;
}
%end

%hook UICKeyChainStore
- (NSString *)accessGroup {
    NSString *group = SCIAvailableKeychainAccessGroup();
    if (group.length > 0) return group;
    return %orig;
}
%end

// A development signing receipt path can make Instagram treat this as TestFlight.
%hook NSBundle
- (NSURL *)appStoreReceiptURL {
    NSURL *original = %orig;
    if (self == [NSBundle mainBundle] && [original.lastPathComponent isEqualToString:@"sandboxReceipt"]) {
        return [[original URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"receipt"];
    }
    return original;
}
%end
