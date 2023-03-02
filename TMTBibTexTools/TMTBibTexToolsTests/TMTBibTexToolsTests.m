//
//  TMTBibTexToolsTests.m
//  TMTBibTexToolsTests
//
//  Created by Tobias Mende on 25.10.15.
//  Copyright © 2015 Tobias Mende. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TMTBibTexTools.h"
#import "TMTBibTexParser.h"
#import "TMTBibTexEntry.h"

@interface TMTBibTexToolsTests : XCTestCase

@end

@implementation TMTBibTexToolsTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (NSString *)loadFileContentWithPath:(NSString *)path
{
    NSError *error;
    NSStringEncoding encoding;
    NSString *content = [NSString stringWithContentsOfFile:path usedEncoding:&encoding error:&error];

    if (error) {
        return nil;
    } else {
//        self.fileEncoding = [NSNumber numberWithUnsignedLong:encoding];
        return content;
    }
}

- (void)testExample {
    
    NSString *pathOld = [[NSBundle mainBundle] pathForResource:@"cycloid" ofType:@"tex"];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"cycloid" ofType:@"tex"];
    

    NSString *filePath1 = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"cycloid.tex"];
    NSString *filePath2 = [[NSBundle bundleForClass:[self class]] pathForResource:@"cycloid" ofType:@"tex"];
    
    
    NSString *content = [self loadFileContentWithPath:filePath2];
    if (!content) { return; }
    
    TMTBibTexParser *parser = [TMTBibTexParser new];
    NSMutableArray *entries = [parser parseBibTexIn:content];
    
    for (TMTBibTexEntry *entry in entries) {
        NSLog(@"key = %@", entry.key);
        NSLog(@"type = %@", entry.type);
        NSLog(@"author = %@", entry.author);
        NSLog(@"title = %@", entry.title);
        NSLog(@"bibtex = %@", entry.bibtex);
        NSLog(@"xml = %@", entry.xml);
    }

}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
