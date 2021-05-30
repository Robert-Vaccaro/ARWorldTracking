//
//  SKWorldTransform.h
//  ARWorldTracking
//
//  Created by Bobby on 4/8/21.
//

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SKWorldTransform : NSObject
@property(nonatomic) int arucoId;
@property(nonatomic) SCNMatrix4 transform;

@end

NS_ASSUME_NONNULL_END
