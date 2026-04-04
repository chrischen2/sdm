//
//  SMKExperimentEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/16/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKExperimentEnumerator.h"
#import "SMKExperiment.h"
#import "SMKDeviceEnumerator.h"
#import "SMKSourceEnumerator.h"
#import "SMKEpochGroupEnumerator.h"
#import "SMKNote.h"
#import "MACHdf5Reader.h"

@interface SMKExperimentEnumeratorTest : SMKBaseTestCase {
    SMKExperimentEnumerator *_enumerator;
}

@end

@implementation SMKExperimentEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *experiment = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468";
    
    _enumerator = [[SMKExperimentEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:experiment, nil]];
}

- (void)testNextObject
{
    int i = 0;
    while ([_enumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 1);
}

- (void)testUuid
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    XCTAssertTrue([experiment.uuid isEqualToString:@"ed6102df-f6c0-4ce0-81d9-4dae15dbe468"]);
}

- (void)testPurpose
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    XCTAssertTrue([experiment.purpose isEqualToString:@"my purpose here"]);
}

- (void)testStartTime
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];

    XCTAssertTrue([[dateFormatter stringFromDate:experiment.startTime] isEqualToString:@"2016-03-16 13:19:19 -0700"]);
}

- (void)testEndTime
{
    SMKExperiment *experiment = [_enumerator nextObject];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];
    
    XCTAssertTrue([[dateFormatter stringFromDate:experiment.endTime] isEqualToString:@"2016-03-16 13:25:39 -0700"]);
}

- (void)testProperties
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Mark Cafaro", @"experimenter",
                              @"Awesome project", @"project",
                              @"UW", @"institution",
                              @"Rieke lab", @"lab",
                              nil];
    
    XCTAssertTrue([experiment.properties isEqualToDictionary:expected]);
}

- (void)testNotes
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    SMKNote *note1 = [SMKNote new];
    note1.timestamp = [NSDate date];
    note1.comment = @"one note here";
    
    SMKNote *note2 = [SMKNote new];
    note2.timestamp = [NSDate date];
    note2.comment = @"and then comes another note";
    
    SMKNote *note3 = [SMKNote new];
    note3.timestamp = [NSDate date];
    note3.comment = @"these are experiment notes";
    
    NSSet *expected = [NSSet setWithObjects:note1, note2, note3, nil];
    
    //XCTAssertTrue([experiment.notes isEqualToSet:expected]);
}

- (void)testKeywords
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    XCTAssertTrue([experiment.keywords count] == 0);
}

- (void)testDeviceEnumerator
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    SMKDeviceEnumerator *deviceEnumerator = experiment.deviceEnumerator;
    
    int i = 0;
    while ([deviceEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 6);
}

- (void)testSourceEnumerator
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    SMKSourceEnumerator *sourceEnumerator = experiment.sourceEnumerator;
    
    int i = 0;
    while ([sourceEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 1);
}

- (void)testEpochGroupEnumerator
{
    SMKExperiment *experiment = [_enumerator nextObject];
    
    SMKEpochGroupEnumerator *groupEnumerator = experiment.epochGroupEnumerator;
    
    int i = 0;
    while ([groupEnumerator nextObject]) {
        i++;
    }
    XCTAssertTrue(i == 2);
}

@end
