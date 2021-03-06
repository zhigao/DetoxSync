//
//  DTXSyncResource.h
//  DetoxSync
//
//  Created by Leo Natan (Wix) on 7/28/19.
//  Copyright © 2019 wix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTXSyncResource : NSObject

- (void)performUpdateBlock:(NSUInteger(^)(void))block eventIdentifier:eventID eventDescription:(NSString*)eventDescription objectDescription:(NSString*)objectDescription additionalDescription:(nullable NSString*)additionalDescription;
- (NSString*)syncResourceGenericDescription;
- (NSString*)syncResourceDescription;

@end

NS_ASSUME_NONNULL_END
