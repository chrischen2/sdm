//
//  SMKEpochBlockEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKEpochBlockEnumerator.h"
#import "SMKEpochBlock.h"
#import "SMKEpochGroup.h"
#import "MACHdf5Reader.h"

@interface SMKEpochBlockEnumeratorTest : SMKBaseTestCase {
    SMKEpochBlockEnumerator *_enumerator;
}

@end

@implementation SMKEpochBlockEnumeratorTest

- (void)setUp
{
    [super setUp];

    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *group = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880/epochBlocks/edu.washington.rieke.protocols.Ramp-a57e1a61-72b5-4e8c-a008-0199c7772384";
    
    _enumerator = [[SMKEpochBlockEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:group, nil]];
}

- (void)testProtocolId
{
    SMKEpochBlock *block = [_enumerator nextObject];
    
    XCTAssertTrue([block.protocolId isEqualToString:@"edu.washington.rieke.protocols.Ramp"]);
}

- (void)testProtocolParameters
{
    SMKEpochBlock *block = [_enumerator nextObject];
    
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Amp1", @"amp",
                              d(0.0), @"interpulseInterval",
                              d(5), @"numberOfAverages",
                              d(50.0), @"preTime",
                              d(100.0), @"rampAmplitude",
                              d(10000.0), @"sampleRate",
                              d(500.0), @"stimTime",
                              d(50.0), @"tailTime",
                              nil];
    
    XCTAssertTrue([block.protocolParameters isEqualToDictionary:expected]);
}

- (void)testEpochEnumerator
{
    SMKEpochBlock *block = [_enumerator nextObject];
    
    SMKEpochEnumerator *epochEnumerator = block.epochEnumerator;
    
    int i = 0;
    while ([epochEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 5);
}

@end
