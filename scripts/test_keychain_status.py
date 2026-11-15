#!/usr/bin/env python3
"""Check the helper's real wrappers preserve statuses and expose only counters."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
args = parser.parse_args()
source = args.source.read_text().split('void rebindSecFuncs()', 1)[0]
source = '\n'.join(line for line in source.splitlines() if not line.startswith('#import'))
program = '''#import <Foundation/Foundation.h>
#import <Security/Security.h>
NSString *accessGroupId = @"fixture-group";
''' + source + '''
static OSStatus fakeRead(CFDictionaryRef query, CFTypeRef *result) { return errSecItemNotFound; }
static OSStatus fakeAdd(CFDictionaryRef query, CFTypeRef *result) { return errSecSuccess; }
static OSStatus fakeUpdate(CFDictionaryRef query, CFDictionaryRef attrs) { return errSecParam; }
static OSStatus fakeDelete(CFDictionaryRef query) { return -34018; }
int main() { @autoreleasepool {
    origSecItemCopyMatching = fakeRead; origSecItemAdd = fakeAdd;
    origSecItemUpdate = fakeUpdate; origSecItemDelete = fakeDelete;
    NSDictionary *query = @{@"credential": @"NEVER_EXPORT_THIS_VALUE"};
    CFDictionaryRef input = (__bridge CFDictionaryRef)query;
    for (int i=0; i<2; i++) {
        if (zxSecItemCopyMatching(input, NULL) != errSecItemNotFound) return 1;
        if (zxSecItemAdd(input, NULL) != errSecSuccess) return 2;
        if (zxSecItemUpdate(input, input) != errSecParam) return 3;
        if (zxSecItemDelete(input) != -34018) return 4;
    }
    NSDictionary *snapshot = SCISideloadKeychainStatuses();
    NSDictionary *expected = @{@"read": @{@"-25300": @2}, @"add": @{@"0": @2},
        @"update": @{@"-50": @2}, @"delete": @{@"-34018": @2}};
    if (![snapshot isEqual:expected]) return 5;
    zxSecItemAdd(input, NULL);
    if (![snapshot isEqual:expected]) return 6; // snapshot is independent
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
    NSString *text = [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding];
    if ([text containsString:@"NEVER_EXPORT"] || [text containsString:@"fixture-group"]) return 7;
    return 0;
}}
'''
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    path = root / 'probe.mm'
    path.write_text(program)
    subprocess.run(['clang++', '-fobjc-arc', '-framework', 'Foundation', '-framework', 'Security', str(path), '-o', str(root / 'probe')], check=True)
    subprocess.run([str(root / 'probe')], check=True)
print('Keychain wrapper return values, counter snapshots, and credential-free report checks passed')
