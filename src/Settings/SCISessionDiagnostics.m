#import "SCISessionDiagnostics.h"
#import "../InstagramHeaders.h"
#import "../Features/General/SessionCompatibility.h"
#import <Security/Security.h>
#import <dlfcn.h>

static NSString * const SCIProbeValue = @"SCInsta harmless persistence marker v1";

static NSString *SCIFileProbe(NSURL *url) {
    if (!url) return @"unavailable";
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL retained = [[NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil] isEqualToString:SCIProbeValue];
    NSError *error = nil;
    [manager createDirectoryAtURL:[url URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
    if (!error) [SCIProbeValue writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&error];
    return error ? [NSString stringWithFormat:@"write error %ld", (long)error.code] : (retained ? @"retained" : @"new marker");
}

static NSString *SCIPreferencesProbe(NSUserDefaults *defaults) {
    if (!defaults) return @"unavailable";
    NSString *key = @"SCISessionDiagnosticMarkerV1";
    BOOL retained = [[defaults stringForKey:key] isEqualToString:SCIProbeValue];
    [defaults setObject:SCIProbeValue forKey:key];
    BOOL synchronized = [defaults synchronize];
    return [NSString stringWithFormat:@"%@ (sync %@)", retained ? @"retained" : @"new marker", synchronized ? @"yes" : @"no"];
}

static NSDictionary *SCICaptureStorageProbes(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *group = SCISessionAccessGroupForDiagnostics();
    NSString *previousGroup = [defaults stringForKey:@"SCIDiagnosticPreviousGroupV1"];
    NSString *groupState = group.length ? (previousGroup ? ([previousGroup isEqualToString:group] ? @"same as prior check" : @"changed since prior check") : @"available; first check") : @"unavailable";
    if (group.length) [defaults setObject:group forKey:@"SCIDiagnosticPreviousGroupV1"];

    NSURL *library = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *file = [library URLByAppendingPathComponent:@"SCInstaDiagnostics/marker-v1.txt"];
    // Empty requests follow the same helper fallback as Instagram's earlier nil request.
    NSURL *appGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@""];
    NSURL *groupFile = [appGroup URLByAppendingPathComponent:@"SCInsta-diagnostic-marker-v1.txt"];

    // Read only our exact, harmless keychain marker; never enumerate login items.
    NSMutableDictionary *query = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: @"SCInstaPersistenceMarkerV1",
        (__bridge id)kSecAttrService: @"com.danzola.scinsta.diagnostics",
        (__bridge id)kSecReturnData: @YES
    } mutableCopy];
    if (group.length) query[(__bridge id)kSecAttrAccessGroup] = group;
    CFTypeRef result = NULL;
    OSStatus readStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    BOOL retained = NO;
    if (result != NULL) {
        id value = CFBridgingRelease(result);
        retained = [value isKindOfClass:[NSData class]] && [value isEqual:[SCIProbeValue dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSString *keychainState = retained ? @"retained" : @"not retained";
    NSMutableString *keychain = [NSMutableString stringWithFormat:@"%@ (read %d)", keychainState, (int)readStatus];
    if (readStatus == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        [item removeObjectForKey:(__bridge id)kSecReturnData];
        item[(__bridge id)kSecValueData] = [SCIProbeValue dataUsingEncoding:NSUTF8StringEncoding];
        OSStatus writeStatus = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        CFTypeRef verified = NULL;
        OSStatus verifyStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &verified);
        if (verified != NULL) CFRelease(verified);
        [keychain appendFormat:@", add %d, verify %d", (int)writeStatus, (int)verifyStatus];
    }

    return @{
        @"diagnostic_version": @1,
        @"keychain_marker": keychain,
        @"available_group": groupState,
        @"app_file_marker": SCIFileProbe(file),
        @"app_group_file_marker": SCIFileProbe(groupFile),
        @"standard_preferences": SCIPreferencesProbe(defaults),
        @"group_preferences": SCIPreferencesProbe([[NSUserDefaults alloc] initWithSuiteName:@"group.com.burbn.instagram"])
    };
}

@implementation SCISessionDiagnostics
+ (void)show {
    // Keep the first observation for this process so reopening the sheet cannot
    // mistake a just-created marker for one surviving a process restart.
    static NSDictionary *storage;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ storage = SCICaptureStorageProbes(); });
    NSMutableDictionary *report = [storage mutableCopy];
    typedef NSDictionary *(*StatusReportFunction)(void);
    StatusReportFunction counters = (StatusReportFunction)dlsym(RTLD_DEFAULT, "SCISideloadKeychainStatuses");
    NSDictionary *statuses = counters ? counters() : nil;
    report[@"keychain_api_status_counts"] = statuses ?: @{@"telemetry": @"unavailable"};
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    NSString *text = [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
    NSMutableString *message = [NSMutableString stringWithFormat:@"Test markers only; no login data.\n\nKeychain: %@\nKeychain group: %@\nApp file: %@\nApp-group file: %@\nPreferences: %@\nGroup preferences: %@", report[@"keychain_marker"], report[@"available_group"], report[@"app_file_marker"], report[@"app_group_file_marker"], report[@"standard_preferences"], report[@"group_preferences"]];
    if (statuses) [message appendFormat:@"\n\nAPI status counts:\n%@", statuses];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Session storage check" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy report" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = text;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [topMostController() presentViewController:alert animated:YES completion:nil];
}
@end
