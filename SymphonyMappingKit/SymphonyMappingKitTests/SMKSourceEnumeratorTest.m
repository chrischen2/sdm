//
//  SMKSourceEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKSourceEnumerator.h"
#import "SMKSource.h"
#import "MACHdf5Reader.h"

@interface SMKSourceEnumeratorTest : SMKBaseTestCase {
    SMKSourceEnumerator *_enumerator;
}

@end

@implementation SMKSourceEnumeratorTest

- (void)setUp
{
    [super setUp];

    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *source = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/sources/source-8de715a4-60f0-4dc3-baae-371e9ab93858";
    
    _enumerator = [[SMKSourceEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:source, nil]];
}

- (void)testLabel
{
    SMKSource *source = [_enumerator nextObject];
    
    XCTAssertTrue([source.label isEqualToString:@"Mouse"]);
}

- (void)testSourceEnumerator
{
    SMKSource *source = [_enumerator nextObject];
    
    SMKSourceEnumerator *sourceEnumerator = source.sourceEnumerator;
    
    int i = 0;
    while ([sourceEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 1);
}

- (void)testProperties
{
    SMKSource *source = [_enumerator nextObject];
    
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"21", @"age",
                              @"overnight", @"darkAdaptation",
                              @"", @"description",
                              @"[\"C57B6\",\"Arr1 KO\",\"GCAP KO\"]", @"genotype",
                              @"my mouse id", @"id",
                              @"male", @"sex",
                              @"heavy", @"weight",
                              nil];
    
    XCTAssertTrue([source.properties isEqualToDictionary:expected]);
}

@end
