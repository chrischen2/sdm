//
//  Response.h
//  AcqUI
//
//  Created by Barry Wark on 12/29/06.
//  Copyright 2006 Barry Wark. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "IOBase.h"

@class Epoch;
@class BWNumericData;

@interface Response :  IOBase  
{
    BOOL needsToSaveData;
}

@property (retain) BWNumericData * data;
@property (retain) NSString * dataUUID;
@property (retain) Epoch * epoch;

@property (assign) BOOL needsToSaveData;
@end
