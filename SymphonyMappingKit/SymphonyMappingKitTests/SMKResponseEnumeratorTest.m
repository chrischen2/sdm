//
//  SMKResponseEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKResponseEnumerator.h"
#import "SMKResponse.h"
#import "MACHdf5Reader.h"

@interface SMKResponseEnumeratorTest : SMKBaseTestCase {
    SMKResponseEnumerator *_enumerator;
}

@end

@implementation SMKResponseEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *response = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880/epochBlocks/edu.washington.rieke.protocols.Ramp-a57e1a61-72b5-4e8c-a008-0199c7772384/epochs/epoch-49ad6fe8-4745-4c55-833e-15c9b927c60e/responses/Amp1-5b846772-9368-4e44-9d17-78db31c21f6c";
    
    _enumerator = [[SMKResponseEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:response, nil]];
}

- (void)testData
{
    SMKResponse *response = [_enumerator nextObject];
    
    // TODO: need better check for data
    XCTAssertTrue(response.data.length == 48000);
}

- (void)testUnits
{
    SMKResponse *response = [_enumerator nextObject];
    
    XCTAssertTrue([response.units isEqualToString:@"pA"]);
}

- (void)testSampleRate
{
    SMKResponse *response = [_enumerator nextObject];
    
    XCTAssertTrue([response.sampleRate isEqualToNumber:[NSNumber numberWithDouble:10000.0]]);
}

- (void)testSampleRateUnits
{
    SMKResponse *response = [_enumerator nextObject];
    
    XCTAssertTrue([response.sampleRateUnits isEqualToString:@"Hz"]);
}

- (void)testInputTime
{
    SMKResponse *response = [_enumerator nextObject];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
    
    XCTAssertTrue([[dateFormatter stringFromDate:response.inputTime] isEqualToString:@"2016-03-16 13:23:48 -0700"]);
}

@end
