//
//  _DTXObjectDeallocHelper.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/6/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "_DTXObjectDeallocHelper.h"
#import "DTXSyncResource.h"
#import "DTXSyncManager-Private.h"

@implementation _DTXObjectDeallocHelper

- (instancetype)initWithSyncResource:(__kindof DTXSyncResource*)syncResource
{
	self = [super init];
	if(self) { _syncResource = syncResource; }
	return self;
}

- (void)dealloc
{
	if(self.performOnDealloc != nil)
	{
		self.performOnDealloc();
	}
	
	if(_syncResource != nil)
	{
		[DTXSyncManager unregisterSyncResource:_syncResource];
		_syncResource = nil;
	}
}

@end
