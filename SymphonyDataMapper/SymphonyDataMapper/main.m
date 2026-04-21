//
//  main.m
//  SymphonyDataMapper
//
//  Created by Mark Cafaro on 1/3/13.
//  Copyright (c) 2013 Rieke Lab. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <SymphonyMappingKit/SMKExperimentMapper.h>
#import "AUIModel/Experiment.h"

int usage()
{
    printf("usage: sdm2 dataFile\n");
    return 1;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSError *error;

        if (argc != 2) {
            return usage();
        }

        NSFileManager* fileManager = [NSFileManager defaultManager];

        NSString *dataFilePath = [NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding];

        if (![fileManager isReadableFileAtPath:dataFilePath]) {
            printf("File is not readable or does not exist: %s\n", [dataFilePath cStringUsingEncoding:NSASCIIStringEncoding]);
            return 1;
        }

        NSString *filename = [[dataFilePath lastPathComponent] stringByDeletingPathExtension];
        NSString *auisqlFilePath = [filename stringByAppendingString:@".auisql"];
        NSString *auisqlHdf5FilePath = [filename stringByAppendingString:@".auisql.h5"];

        if ([fileManager fileExistsAtPath:auisqlFilePath]) {
            char response;

            printf("Database file %s already exists.\n", [auisqlFilePath cStringUsingEncoding:NSASCIIStringEncoding]);

            while (response != 'Y' && response != 'N') {
                printf("Overwriting will devalidate previous OvationExports! Overwrite? [Y/N] ");
                response = getchar();
                while (getchar() != '\n');
            }

            switch (response) {
                case 'Y':
                    if ([fileManager removeItemAtPath:auisqlFilePath error:&error] == NO) {
                        NSLog(@"Couldn't remove existing AUISQL file: %@", error);
                        return 1;
                    }
                    // Also remove stale SQLite WAL/SHM sidecars — leaving them
                    // behind causes Core Data to hit SQLITE_IOERR (522) on open.
                    for (NSString *suffix in @[@"-wal", @"-shm", @"-journal"]) {
                        NSString *sidecar = [auisqlFilePath stringByAppendingString:suffix];
                        if ([fileManager fileExistsAtPath:sidecar]) {
                            [fileManager removeItemAtPath:sidecar error:NULL];
                        }
                    }

                    if ([fileManager fileExistsAtPath:auisqlHdf5FilePath]) {
                        if ([fileManager removeItemAtPath:auisqlHdf5FilePath error:&error] == NO) {
                            NSLog(@"Couldn't remove existing AUISQL HDF5 file: %@", error);
                            return 1;
                        }
                    }
                    break;

                case 'N':
                    return 0;
            }
        }

        NSBundle *modelBundle = [NSBundle bundleForClass:[Experiment class]];
        NSManagedObjectModel *objectModel = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:modelBundle]];
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:objectModel];

        NSURL *auisqlUrl = [NSURL fileURLWithPath:auisqlFilePath];
        id result = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                              configuration:nil
                                                        URL:auisqlUrl
                                                    options:nil
                                                      error:&error];
        if (result == nil) {
            NSLog(@"Failed to initialize auisql store: %@", error);
            return 2;
        }

        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [context setPersistentStoreCoordinator:coordinator];
        [context setUndoManager:nil];

        SMKExperimentMapper *mapper = [SMKExperimentMapper mapperForDataFilePath:dataFilePath
                                                                         context:context
                                                                       auisqlUrl:auisqlUrl];

        @try {
            [mapper map];
        }
        @catch (NSException *exception) {
            NSLog(@"Error: %@", exception);
            return 3;
        }
    }
    return 0;
}
