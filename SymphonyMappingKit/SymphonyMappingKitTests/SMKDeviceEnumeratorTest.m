//
//  SMKDeviceEnumeratorTest.m
//  
//
//  Created by Mark Cafaro on 3/18/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKDeviceEnumerator.h"
#import "SMKDevice.h"
#import "MACHdf5Reader.h"

@interface SMKDeviceEnumeratorTest : SMKBaseTestCase {
    SMKDeviceEnumerator *_enumerator;
}

@end

@implementation SMKDeviceEnumeratorTest

- (void)setUp
{
    [super setUp];
    
    MACHdf5Reader *reader = [MACHdf5Reader readerWithFilePath:[_resourcePath stringByAppendingString:@"2016-03-16.h5"]];
    
    NSString *device = @"/experiment-ed6102df-f6c0-4ce0-81d9-4dae15dbe468/devices/Amp1-d7dc0f73-a246-41ea-aa1d-9c752e5ce572";
    
    _enumerator = [[SMKDeviceEnumerator alloc] initWithReader:reader entityPaths:[NSArray arrayWithObjects:device, nil]];
}

- (void)testName
{
    SMKDevice *device = [_enumerator nextObject];
    
    XCTAssertTrue([device.name isEqualToString:@"Amp1"]);
}

- (void)testManufacturer
{
    SMKDevice *device = [_enumerator nextObject];
    
    XCTAssertTrue([device.manufacturer isEqualToString:@"Molecular Devices"]);
}

@end
