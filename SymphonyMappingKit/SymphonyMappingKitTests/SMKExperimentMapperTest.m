//
//  SMKExperimentMapperTest.m
//  
//
//  Created by Mark Cafaro on 3/21/16.
//
//

#import "SMKBaseTestCase.h"
#import "SMKExperimentMapper.h"

#import <AUIModel/AUIModel.h>

@interface SMKExperimentMapperTest : SMKBaseTestCase {
    SMKExperimentMapper *_mapper;
    NSManagedObjectContext *_context;
}

@end

@implementation SMKExperimentMapperTest

- (void)setUp
{
    [super setUp];
    
    NSBundle *modelBundle = [NSBundle bundleForClass:[Experiment class]];
    NSManagedObjectModel *objectModel = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:modelBundle]];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:objectModel];
    [coordinator addPersistentStoreWithType:NSInMemoryStoreType
                              configuration:nil
                                        URL:nil
                                    options:nil
                                      error:nil];
    
    _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_context setPersistentStoreCoordinator:coordinator];
    
    NSString *dataFile = [self pathForResource:@"2016-03-16.h5"];
    
    // Need a temp file just so the mapper won't complain
    NSURL *auisqlUrl = [NSURL fileURLWithPath:@"2016-03-16.auisql"];
    [[NSFileManager defaultManager] createFileAtPath:auisqlUrl.path contents:nil attributes:nil];
    
    // Remove any pre-existing data file from last run
    NSURL *dataFileUrl = [NSURL fileURLWithPath:@"2016-03-16.auisql.h5"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dataFileUrl.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:dataFileUrl error:nil];
    }
    
    _mapper = [SMKExperimentMapper mapperForDataFilePath:dataFile
                                                 context:_context
                                               auisqlUrl:auisqlUrl];
}

- (void)testResponseMapping
{
    [_mapper map];
    
    NSEntityDescription *description = [NSEntityDescription entityForName:@"Epoch"
                                                   inManagedObjectContext:_context];
    
    NSFetchRequest *request = [NSFetchRequest new];
    request.entity = description;
    
    NSDate *dotNetRefDate = [NSDate dateWithString:@"0001-01-01 00:00:00 +0000"];
    NSDate *startDate = [NSDate dateWithTimeInterval:(635937314277670113 / 1e7 - (-7.0 * 60 * 60)) sinceDate:dotNetRefDate];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"startDate = %@", startDate];
    request.predicate = predicate;
    
    NSArray *result = [_context executeFetchRequest:request error:nil];
    
    Epoch *epoch = [result objectAtIndex:0];
    
    Response *response = [epoch responseWithChannelID:0 ofType:ANALOG_IN];
    
    NSData *data = response.data;
    
    double test = 50.0;
    [data getBytes:&test length:sizeof(double)];
    
    XCTAssertTrue(test == 0.0);
    XCTAssertTrue(data.length == 48000);
}

@end
