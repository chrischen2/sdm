//
//  SMKBaseTestCase.h
//  SymphonyMapperKit
//
//  Created by Mark Cafaro on 1/2/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

@import XCTest;

#define d(n) [NSNumber numberWithDouble:n]
#define ll(n) [NSNumber numberWithLongLong:n]
#define i(n) [NSNumber numberWithInt:n]
#define f(n) [NSNumber numberWithFloat:n]

@interface SMKBaseTestCase : XCTestCase {
    NSString *_resourcePath;
}

- (NSString *)pathForResource:(NSString *)filename;

@end
