//
//  SMKStimulusEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKStimulusEnumerator.h"
#import "SMKStimulus.h"
#import "MACHdf5Reader.h"

@interface SMKStimulusEnumeratorTest : SMKBaseTestCase {
    SMKStimulusEnumerator *_enumerator;
}

@end

@implementation SMKStimulusEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *stimulus = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/epochGroups/epochGroup-3a039d15-0d95-4b33-9deb-6ffe297aa880/epochBlocks/edu.washington.rieke.protocols.Ramp-a57e1a61-72b5-4e8c-a008-0199c7772384/epochs/epoch-49ad6fe8-4745-4c55-833e-15c9b927c60e/stimuli/Amp1-b10324b8-8b2e-4cc7-ae52-11bbd434341a";
    
    _enumerator = [[SMKStimulusEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:stimulus, nil]];
}

- (void)testStimulusId
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    XCTAssertTrue([stimulus.stimulusId isEqualToString:@"symphonyui.builtin.stimuli.RampGenerator"]);
}

- (void)testUnits
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    XCTAssertTrue([stimulus.units isEqualToString:@"V"]);
}

- (void)testSampleRate
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    XCTAssertTrue([stimulus.sampleRate isEqualToNumber:[NSNumber numberWithDouble:10000.0]]);
}

- (void)testSampleRateUnits
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    XCTAssertTrue([stimulus.sampleRateUnits isEqualToString:@"Hz"]);
}

- (void)testParameters
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              d(100.0), @"amplitude",
                              d(0.0), @"mean",
                              d(50.0), @"preTime",
                              d(10000.0), @"sampleRate",
                              d(500.0), @"stimTime",
                              d(50.0), @"tailTime",
                              @"mV", @"units",
                              nil];
    
    XCTAssertTrue([stimulus.parameters isEqualToDictionary:expected]);
}

- (void)testDuration
{
    SMKStimulus *stimulus = [_enumerator nextObject];
    
    XCTAssertTrue(stimulus.duration == 0.6);
}

@end
