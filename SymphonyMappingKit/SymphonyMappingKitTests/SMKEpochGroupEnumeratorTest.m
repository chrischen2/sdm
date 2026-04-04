//
//  SMKEpochGroupEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKEpochGroupEnumerator.h"
#import "SMKEpochGroup.h"
#import "SMKEpochBlockEnumerator.h"
#import "SMKSource.h"
#import "MACHdf5Reader.h"

@interface SMKEpochGroupEnumeratorTest : SMKBaseTestCase {
    SMKEpochGroupEnumerator *_enumerator;
}

@end

@implementation SMKEpochGroupEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *group = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880";
    
    _enumerator = [[SMKEpochGroupEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:group, nil]];
}

- (void)testLabel
{
    SMKEpochGroup *group = [_enumerator nextObject];
    
    XCTAssertTrue([group.label isEqualToString:@"Drug"]);
}

- (void)testSource
{
    SMKEpochGroup *group = [_enumerator nextObject];
    
    SMKSource *source = group.source;
    
    XCTAssertTrue([source.uuid isEqualToString:@"fcd15c51-a104-47e9-bae1-b98a180ce114"]);
}

- (void)testEpochGroupEnumerator
{
    SMKEpochGroup *group = [_enumerator nextObject];
    
    SMKEpochGroupEnumerator *groupEnumerator = group.epochGroupEnumerator;
    
    int i = 0;
    while ([groupEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 1);
}

- (void)testEpochBlockEnumerator
{
    SMKEpochGroup *group = [_enumerator nextObject];
    
    SMKEpochBlockEnumerator *blockEnumerator = group.epochBlockEnumerator;
    
    int i = 0;
    while ([blockEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 1);
}

@end
