//
//  DTXReactNativeSupport.m
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 8/14/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import "DTXReactNativeSupport.h"
#import "ReactNativeHeaders.h"
#import "DTXSyncManager-Private.h"
#import "DTXJSTimerSyncResource.h"
#import "DTXSingleUseSyncResource.h"
#import <dlfcn.h>
#import <stdatomic.h>
#import <fishhook.h>

@import UIKit;
@import ObjectiveC;
@import Darwin;

DTX_CREATE_LOG(DTXReactNativeSupport);

atomic_cfrunloop __RNRunLoop;
static atomic_constvoidptr __RNThread;
static void (*orig_runRunLoopThread)(id, SEL) = NULL;
static void swz_runRunLoopThread(id self, SEL _cmd)
{
	CFRunLoopRef oldRunloop = atomic_load(&__RNRunLoop);
	
	CFRunLoopRef current = CFRunLoopGetCurrent();
	atomic_store(&__RNRunLoop, current);
	
	NSThread* oldThread = CFBridgingRelease(atomic_load(&__RNThread));
	
	atomic_store(&__RNThread, CFBridgingRetain([NSThread currentThread]));

	[DTXSyncManager trackThread:[NSThread currentThread]];
	[DTXSyncManager untrackThread:oldThread];
	[DTXSyncManager trackCFRunLoop:current];
	[DTXSyncManager untrackCFRunLoop:oldRunloop];
	
	oldThread = nil;
	
	orig_runRunLoopThread(self, _cmd);
}

static NSMutableArray* _observedQueues;

static int (*__orig__UIApplication_run_orig)(id self, SEL _cmd);
static int __detox_sync_UIApplication_run(id self, SEL _cmd)
{
	Class cls = NSClassFromString(@"RCTJSCExecutor");
	Method m = NULL;
	if(cls != NULL)
	{
		//Legacy RN
		m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoopThread"));
		dtx_log_info(@"Found legacy class RCTJSCExecutor");
	}
	else
	{
		//Modern RN
		cls = NSClassFromString(@"RCTCxxBridge");
		m = class_getClassMethod(cls, NSSelectorFromString(@"runRunLoop"));
		if(m == NULL)
		{
			m = class_getInstanceMethod(cls, NSSelectorFromString(@"runJSRunLoop"));
			dtx_log_info(@"Found modern class RCTCxxBridge, method runJSRunLoop");
		}
		else
		{
			dtx_log_info(@"Found modern class RCTCxxBridge, method runRunLoop");
		}
	}
	
	if(m != NULL)
	{
		orig_runRunLoopThread = (void(*)(id, SEL))method_getImplementation(m);
		method_setImplementation(m, (IMP)swz_runRunLoopThread);
	}
	else
	{
		dtx_log_info(@"Method runRunLoop not found");
	}
	
	return __orig__UIApplication_run_orig(self, _cmd);
}

typedef void (^RCTSourceLoadBlock)(NSError *error, id source);

static void (*__orig_loadBundleAtURL_onProgress_onComplete)(id self, SEL _cmd, NSURL* url, id onProgress, RCTSourceLoadBlock onComplete);
static void __detox_sync_loadBundleAtURL_onProgress_onComplete(id self, SEL _cmd, NSURL* url, id onProgress, RCTSourceLoadBlock onComplete)
{
	[DTXReactNativeSupport cleanupBeforeReload];
	
	dtx_log_info(@"Adding idling resource for RN load");
	
	id<DTXSingleUse> sr = [DTXSingleUseSyncResource singleUseSyncResourceWithObjectDescription:[self description] eventDescription:@"React Native (Bundle Load)"];
	
	[DTXReactNativeSupport waitForReactNativeLoadWithCompletionHandler:^{
		[sr endTracking];
	}];
	
	__orig_loadBundleAtURL_onProgress_onComplete(self, _cmd, url, onProgress, onComplete);
}

__attribute__((constructor))
static void _setupRNSupport()
{
	@autoreleasepool
	{
		Class cls = NSClassFromString(@"RCTModuleData");
		if(cls == nil)
		{
			return;
		}
		
		_observedQueues = [NSMutableArray new];
		
		//Add an idling resource for each module queue.
		Method m = class_getInstanceMethod(cls, NSSelectorFromString(@"setUpMethodQueue"));
		void(*orig_setUpMethodQueue_imp)(id, SEL) = (void(*)(id, SEL))method_getImplementation(m);
		method_setImplementation(m, imp_implementationWithBlock(^(id _self) {
			orig_setUpMethodQueue_imp(_self, NSSelectorFromString(@"setUpMethodQueue"));
			
			dispatch_queue_t queue = object_getIvar(_self, class_getInstanceVariable(cls, "_methodQueue"));
			
			if(queue != nil && [queue isKindOfClass:[NSNull class]] == NO && queue != dispatch_get_main_queue() && [_observedQueues containsObject:queue] == NO)
			{
				NSString* queueName = [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue) ?: queue.description.UTF8String];
				
				[_observedQueues addObject:queue];
				
				DTXSyncResourceVerboseLog(@"Adding sync resource for queue: %@", queueName);
				
				[DTXSyncManager trackDispatchQueue:queue];
			}
		}));
		
		//Cannot just extern this function - we are not linked with RN, so linker will fail. Instead, look for symbol in runtime.
		dispatch_queue_t (*RCTGetUIManagerQueue)(void) = dlsym(RTLD_DEFAULT, "RCTGetUIManagerQueue");
		
		//Must be performed in +load and not in +setUp in order to correctly catch the ui queue, runloop and display link initialization by RN.
		dispatch_queue_t queue = RCTGetUIManagerQueue();
		
		[DTXSyncManager trackDispatchQueue:queue];
		
		[_observedQueues addObject:queue];
		
		DTXSyncResourceVerboseLog(@"Adding sync resource for RCTUIManagerQueue");
		
		[DTXSyncManager trackDispatchQueue:queue];
		
		m = class_getInstanceMethod(UIApplication.class, NSSelectorFromString(@"_run"));
		__orig__UIApplication_run_orig = (void*)method_getImplementation(m);
		method_setImplementation(m, (void*)__detox_sync_UIApplication_run);
		
		DTXSyncResourceVerboseLog(@"Adding sync resource for JS timers");
		
		DTXJSTimerSyncResource* sr = [DTXJSTimerSyncResource new];
		[DTXSyncManager registerSyncResource:sr];
		
//		//TODO:
//		if([WXAnimatedDisplayLinkIdlingResource isAvailable]) {
//			_DTXSyncResourceVerboseLog(@"Adding idling resource for Animated display link");
//			
//			[[GREYUIThreadExecutor sharedInstance] registerIdlingResource:[WXAnimatedDisplayLinkIdlingResource new]];
//		}
		
		cls = NSClassFromString(@"RCTJavaScriptLoader");
		if(cls == nil)
		{
			return;
		}
		
		m = class_getClassMethod(cls, NSSelectorFromString(@"loadBundleAtURL:onProgress:onComplete:"));
		if(m == NULL)
		{
			return;
		}
		__orig_loadBundleAtURL_onProgress_onComplete = (void*)method_getImplementation(m);
		method_setImplementation(m, (void*)__detox_sync_loadBundleAtURL_onProgress_onComplete);
	}
}

@implementation DTXReactNativeSupport

+ (BOOL)hasReactNative
{
	return (NSClassFromString(@"RCTBridge") != nil);
}

+ (void)waitForReactNativeLoadWithCompletionHandler:(void (^)(void))handler
{
	__block __weak id observer;
	
	observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"RCTJavaScriptDidLoadNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
		if(handler)
		{
			handler();
		}
		
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	}];
}

+ (void)cleanupBeforeReload
{
	for (dispatch_queue_t queue in _observedQueues) {
		[DTXSyncManager untrackDispatchQueue:queue];
	}
}

@end
