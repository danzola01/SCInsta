#!/usr/bin/env python3
"""Exercise the helper's actual Objective-C method body on hosted macOS."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('--expect-crash', action='store_true')
args = parser.parse_args()
source = args.source.read_text()
body = source.split('%hook NSFileManager\n', 1)[1].split('%end', 1)[0]
program = '''#import <Foundation/Foundation.h>
NSURL *getAppGroupPathIfExists() { return [NSURL fileURLWithPath:NSTemporaryDirectory()]; }
BOOL createDirectoryIfNotExists(NSString *path) { return YES; }
@interface GroupProbe : NSObject
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)identifier;
@end
@implementation GroupProbe
''' + body + '''\n@end
int main() {
    @autoreleasepool {
        @try {
            GroupProbe *probe = [GroupProbe new];
            NSURL *nilResult = [probe containerURLForSecurityApplicationGroupIdentifier:nil];
            NSURL *emptyResult = [probe containerURLForSecurityApplicationGroupIdentifier:@""];
            NSURL *namedResult = [probe containerURLForSecurityApplicationGroupIdentifier:@"group.test"];
            if (![[nilResult lastPathComponent] isEqualToString:@"group.com.burbn.instagram"]) return 2;
            if (![emptyResult isEqual:nilResult]) return 3;
            if (![[namedResult lastPathComponent] isEqualToString:@"group.test"]) return 4;
            return 0;
        } @catch (NSException *exception) {
            fprintf(stderr, "%s: %s\\n", exception.name.UTF8String, exception.reason.UTF8String);
            return 10;
        }
    }
}
'''
with tempfile.TemporaryDirectory() as temporary:
    path = Path(temporary)
    (path / 'probe.m').write_text(program)
    subprocess.run(['clang', '-fobjc-arc', '-framework', 'Foundation', str(path / 'probe.m'), '-o', str(path / 'probe')], check=True)
    result = subprocess.run([str(path / 'probe')])
    expected = 10 if args.expect_crash else 0
    if result.returncode != expected:
        raise SystemExit(f'Expected status {expected}; got {result.returncode}')
    print('Original nil-group crash reproduced' if args.expect_crash else 'Patched nil/empty/named group checks passed')
