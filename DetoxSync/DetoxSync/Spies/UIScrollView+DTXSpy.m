//
//  UIScrollView+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "UIScrollView+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

static const void* _DTXScrollViewSRKey = &_DTXScrollViewSRKey;

@interface UIScrollView ()

- (void)_scrollViewWillBeginDragging;
- (void)_scrollViewDidEndDraggingWithDeceleration:(_Bool)arg1;
- (void)_scrollViewDidEndDecelerating;

@end

@implementation UIScrollView (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		NSError* error;
		[self jr_swizzleMethod:@selector(_scrollViewWillBeginDragging) withMethod:@selector(__detox_sync__scrollViewWillBeginDragging) error:&error];
		[self jr_swizzleMethod:@selector(_scrollViewDidEndDraggingWithDeceleration:) withMethod:@selector(__detox_sync__scrollViewDidEndDraggingWithDeceleration:) error:&error];
		[self jr_swizzleMethod:@selector(_scrollViewDidEndDecelerating) withMethod:@selector(__detox_sync__scrollViewDidEndDecelerating) error:&error];
	}
}

- (void)__detox_sync__scrollViewWillBeginDragging
{
	DTXSingleUseSyncResource* sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:self.description eventDescription:@"Scroll View Scroll"];
	objc_setAssociatedObject(self, _DTXScrollViewSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self __detox_sync__scrollViewWillBeginDragging];
}

- (void)__detox_sync_resetSyncResource
{
	DTXSingleUseSyncResource* sr = objc_getAssociatedObject(self, _DTXScrollViewSRKey);
	[sr endTracking];
	objc_setAssociatedObject(self, _DTXScrollViewSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)__detox_sync__scrollViewDidEndDraggingWithDeceleration:(bool)arg1
{
	[self __detox_sync__scrollViewDidEndDraggingWithDeceleration:arg1];
	
	if(arg1 == NO)
	{
		[self __detox_sync_resetSyncResource];
	}
}

- (void)__detox_sync__scrollViewDidEndDecelerating
{
	[self __detox_sync__scrollViewDidEndDecelerating];
	
	[self __detox_sync_resetSyncResource];
}

@end
