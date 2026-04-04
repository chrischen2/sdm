//
//  SMKEpochEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKEpochEnumerator.h"
#import "SMKEpoch.h"
#import "MACHdf5Reader.h"

@interface SMKEpochEnumeratorTest : SMKBaseTestCase {
    SMKEpochEnumerator *_enumerator;
}

@end

@implementation SMKEpochEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *epoch = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880/epochBlocks/edu.washington.rieke.protocols.Ramp-a57e1a61-72b5-4e8c-a008-0199c7772384/epochs/epoch-49ad6fe8-4745-4c55-833e-15c9b927c60e";
    
    _enumerator = [[SMKEpochEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:epoch, nil]];
}

- (void)testProtocolParameters
{
    SMKEpoch *epoch = [_enumerator nextObject];
    
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              d(0.0), @"bathTemperature",
                              nil];
    
    XCTAssertTrue([epoch.protocolParameters isEqualToDictionary:expected]);
}

- (void)testBackgrounds
{
    SMKEpoch *epoch = [_enumerator nextObject];
    
    XCTAssertTrue([epoch.backgrounds count] == 5);
}

- (void)testStimuli
{
    SMKEpoch *epoch = [_enumerator nextObject];
    
    XCTAssertTrue([epoch.stimuli count] == 1);
}

- (void)testResponses
{
    SMKEpoch *epoch = [_enumerator nextObject];
    
    XCTAssertTrue([epoch.responses count] == 1);
}


@end
