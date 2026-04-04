//
//  SMKBackgroundEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKBackgroundEnumerator.h"
#import "SMKBackground.h"
#import "MACHdf5Reader.h"

@interface SMKBackgroundEnumeratorTest : SMKBaseTestCase {
    SMKBackgroundEnumerator *_enumerator;
}

@end

@implementation SMKBackgroundEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *background = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880/epochBlocks/edu.washington.rieke.protocols.Ramp-a57e1a61-72b5-4e8c-a008-0199c7772384/epochs/epoch-49ad6fe8-4745-4c55-833e-15c9b927c60e/backgrounds/Amp1-4454d770-fa09-4293-9454-324197597dbc";
    
    _enumerator = [[SMKBackgroundEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:background, nil]];
}

- (void)testValue
{
    SMKBackground *background = [_enumerator nextObject];
    
    XCTAssertTrue([background.value isEqualToNumber:[NSNumber numberWithDouble:0.0]]);
}

- (void)testUnits
{
    SMKBackground *background = [_enumerator nextObject];
    
    XCTAssertTrue([background.units isEqualToString:@"V"]);
}

- (void)testSampleRate
{
    SMKBackground *background = [_enumerator nextObject];
    
    XCTAssertTrue([background.sampleRate isEqualToNumber:[NSNumber numberWithDouble:10000.0]]);
}

- (void)testSampleRateUnits
{
    SMKBackground *background = [_enumerator nextObject];
    
    XCTAssertTrue([background.sampleRateUnits isEqualToString:@"Hz"]);
}

@end
