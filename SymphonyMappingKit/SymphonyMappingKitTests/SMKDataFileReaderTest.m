//
//  SMKDataFileReaderTest.m
//  
//
//  Created by Mark Cafaro on 3/16/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKDataFileReader.h"
#import "SMKExperimentEnumerator.h"

@interface SMKDataFileReaderTest : SMKBaseTestCase {
    SMKDataFileReader *_reader;
}

@end

@implementation SMKDataFileReaderTest

- (void)setUp
{
    [super setUp];
    
    _reader = [SMKDataFileReader readerForHdf5FilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
}

- (void)testEpochGroupEnumerator
{
    SMKExperimentEnumerator *enumerator = [_reader experimentEnumerator];
    
    int count = 0;
    while ([enumerator nextObject]) {
        count++;
    }
    
    XCTAssertTrue(count == 1);
}

@end
