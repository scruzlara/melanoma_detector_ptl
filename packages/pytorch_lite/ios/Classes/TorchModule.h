// TorchModule.h — ObjC interface for LibTorch mobile inference.
// The C++ types are hidden in the .mm implementation.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TorchModule : NSObject

@property (nonatomic, readonly) int imageWidth;
@property (nonatomic, readonly) int imageHeight;
/// 0 = classification model, >0 = object detection model (number of classes).
@property (nonatomic, readonly) int numberOfClasses;

/// Loads a .ptl model from the given file path.
/// Returns nil if the model cannot be loaded; outError contains the LibTorch message.
+ (nullable TorchModule *)moduleAtPath:(NSString *)filePath
                            imageWidth:(int)imageWidth
                           imageHeight:(int)imageHeight
                       numberOfClasses:(int)numberOfClasses
                                 error:(NSError *_Nullable *_Nullable)outError;

/// Runs classification inference on raw image bytes (JPEG/PNG).
/// Returns the raw output tensor as a flat array of floats, or nil on failure.
- (nullable NSArray<NSNumber *> *)predictImage:(NSData *)imageData
                                          mean:(NSArray<NSNumber *> *)mean
                                           std:(NSArray<NSNumber *> *)std;

/// Runs object detection inference on raw image bytes (JPEG/PNG).
/// Returns an array of detections, each as @[classIndex, score, left, top, right, bottom, width, height].
- (NSArray<NSArray<NSNumber *> *> *)detectObjectsInImage:(NSData *)imageData
                                            minimumScore:(float)minimumScore
                                            IOUThreshold:(float)IOUThreshold
                                              boxesLimit:(int)boxesLimit;

/// Runs inference on a custom flat input tensor.
- (nullable NSArray<NSNumber *> *)predictCustomInput:(NSArray<NSNumber *> *)input
                                               shape:(NSArray<NSNumber *> *)shape
                                               dtype:(NSString *)dtype;

@end

NS_ASSUME_NONNULL_END
