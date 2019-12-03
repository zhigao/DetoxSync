//
//  NSURLSessionTask+DTXSpy.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/4/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "NSURLSessionTask+DTXSpy.h"
#import "DTXSingleUseSyncResource.h"

@import ObjectiveC;

static const void* _DTXNetworkTaskSRKey = &_DTXNetworkTaskSRKey;

@interface NSURLSessionTask ()

- (void)resume;
- (void)connection:(id)arg1 didFinishLoadingWithError:(id)arg2;

@end

@implementation NSURLSessionTask (DTXSpy)

+ (void)load
{
	@autoreleasepool
	{
		Class cls = NSClassFromString(@"__NSCFLocalDataTask");
		
		NSError* error;
		if(NO == [cls jr_swizzleMethod:NSSelectorFromString(@"greyswizzled_resume") withMethod:@selector(__detox_sync_resume) error:&error])
		{
			[cls jr_swizzleMethod:@selector(resume) withMethod:@selector(__detox_sync_resume) error:&error];
		}
		
//		m1 = class_getInstanceMethod(cls, @selector(connection:didFinishLoadingWithError:));
//		m2 = class_getInstanceMethod(self.class, @selector(__detox_sync_connection:didFinishLoadingWithError:));
//		method_exchangeImplementations(m1, m2);
	}
}

- (void)__detox_sync_resume
{
	id<DTXSingleUse> sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:[NSString stringWithFormat:@"URL: “%@”", self.originalRequest.URL.absoluteString] eventDescription:@"Network Request"];
	objc_setAssociatedObject(self, _DTXNetworkTaskSRKey, sr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self __detox_sync_resume];
}

- (void)__detox_sync_untrackTask
{
	id<DTXSingleUse> sr = objc_getAssociatedObject(self, _DTXNetworkTaskSRKey);
	[sr endTracking];
	objc_setAssociatedObject(self, _DTXNetworkTaskSRKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
//
//- (void)__detox_sync_connection:(id)arg1 didFinishLoadingWithError:(id)arg2;
//{
//	[self __detox_sync_connection:arg1 didFinishLoadingWithError:arg2];
//}

@end
