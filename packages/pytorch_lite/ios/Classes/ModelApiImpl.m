// ModelApiImpl.m — ObjC implementation of ModelApi using TorchModule.
#import "ModelApiImpl.h"
#import "TorchModule.h"
#import <Flutter/Flutter.h>

@implementation ModelApiImpl {
    NSMutableDictionary<NSNumber *, TorchModule *> *_models;
    int _nextIndex;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _models    = [NSMutableDictionary new];
        _nextIndex = 0;
    }
    return self;
}

// ---------------------------------------------------------------------------
// loadModel
// ---------------------------------------------------------------------------

- (nullable NSNumber *)loadModelModelPath:(NSString *)modelPath
                          numberOfClasses:(nullable NSNumber *)numberOfClasses
                               imageWidth:(nullable NSNumber *)imageWidth
                              imageHeight:(nullable NSNumber *)imageHeight
                                    error:(FlutterError *_Nullable *_Nonnull)error {
    int w       = imageWidth       ? imageWidth.intValue       : 224;
    int h       = imageHeight      ? imageHeight.intValue      : 224;
    int classes = numberOfClasses  ? numberOfClasses.intValue  : 0;

    NSError *moduleError = nil;
    TorchModule *module = [TorchModule moduleAtPath:modelPath
                                         imageWidth:w
                                        imageHeight:h
                                    numberOfClasses:classes
                                              error:&moduleError];
    if (!module) {
        NSString *reason = moduleError.localizedDescription ?: @"Unknown LibTorch error";
        *error = [FlutterError errorWithCode:@"LOAD_ERROR"
                                     message:reason
                                     details:modelPath];
        return nil;
    }

    int index = _nextIndex++;
    _models[@(index)] = module;
    return @(index);
}

// ---------------------------------------------------------------------------
// getPredictionCustom
// ---------------------------------------------------------------------------

- (void)getPredictionCustomIndex:(NSNumber *)index
                           input:(NSArray<NSNumber *> *)input
                           shape:(NSArray<NSNumber *> *)shape
                           dtype:(NSString *)dtype
                      completion:(void(^)(NSArray *_Nullable, FlutterError *_Nullable))completion {
    TorchModule *model = _models[@(index.intValue)];
    if (!model) {
        completion(nil, [FlutterError errorWithCode:@"MODEL_NOT_FOUND"
                                            message:@"No model at this index"
                                            details:nil]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSNumber *> *result = [model predictCustomInput:input shape:shape dtype:dtype];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result) {
                completion(result, nil);
            } else {
                completion(nil, [FlutterError errorWithCode:@"INFERENCE_ERROR"
                                                    message:@"Custom inference failed"
                                                    details:nil]);
            }
        });
    });
}

// ---------------------------------------------------------------------------
// getImagePredictionList  (classification)
// ---------------------------------------------------------------------------

- (void)getImagePredictionListIndex:(NSNumber *)index
                          imageData:(nullable FlutterStandardTypedData *)imageData
                     imageBytesList:(nullable NSArray *)imageBytesList
            imageWidthForBytesList:(nullable NSNumber *)imageWidthForBytesList
           imageHeightForBytesList:(nullable NSNumber *)imageHeightForBytesList
                               mean:(NSArray<NSNumber *> *)mean
                                std:(NSArray<NSNumber *> *)std
                         completion:(void(^)(NSArray<NSNumber *> *_Nullable,
                                            FlutterError *_Nullable))completion {
    TorchModule *model = _models[@(index.intValue)];
    if (!model) {
        completion(nil, [FlutterError errorWithCode:@"MODEL_NOT_FOUND"
                                            message:@"No model at this index"
                                            details:nil]);
        return;
    }

    // Resolve image bytes: single image takes priority, then first item from list
    NSData *data = nil;
    if (imageData) {
        data = imageData.data;
    } else if (imageBytesList.count > 0) {
        id first = imageBytesList[0];
        if ([first isKindOfClass:[FlutterStandardTypedData class]]) {
            data = ((FlutterStandardTypedData *)first).data;
        }
    }

    if (!data) {
        completion(nil, [FlutterError errorWithCode:@"NO_IMAGE"
                                            message:@"No image data provided"
                                            details:nil]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSNumber *> *result = [model predictImage:data mean:mean std:std];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (result) {
                completion(result, nil);
            } else {
                completion(nil, [FlutterError errorWithCode:@"INFERENCE_ERROR"
                                                    message:@"Image classification failed"
                                                    details:nil]);
            }
        });
    });
}

// ---------------------------------------------------------------------------
// getImagePredictionListObjectDetection
// ---------------------------------------------------------------------------

- (void)getImagePredictionListObjectDetectionIndex:(NSNumber *)index
                                         imageData:(nullable FlutterStandardTypedData *)imageData
                                    imageBytesList:(nullable NSArray *)imageBytesList
                           imageWidthForBytesList:(nullable NSNumber *)imageWidthForBytesList
                          imageHeightForBytesList:(nullable NSNumber *)imageHeightForBytesList
                                     minimumScore:(NSNumber *)minimumScore
                                     IOUThreshold:(NSNumber *)IOUThreshold
                                       boxesLimit:(NSNumber *)boxesLimit
                                       completion:(void(^)(NSArray<ResultObjectDetection *> *_Nullable,
                                                          FlutterError *_Nullable))completion {
    TorchModule *model = _models[@(index.intValue)];
    if (!model) {
        completion(nil, [FlutterError errorWithCode:@"MODEL_NOT_FOUND"
                                            message:@"No model at this index"
                                            details:nil]);
        return;
    }

    NSData *data = nil;
    if (imageData) {
        data = imageData.data;
    } else if (imageBytesList.count > 0) {
        id first = imageBytesList[0];
        if ([first isKindOfClass:[FlutterStandardTypedData class]]) {
            data = ((FlutterStandardTypedData *)first).data;
        }
    }

    if (!data) {
        completion(@[], nil);
        return;
    }

    float minScore   = minimumScore.floatValue;
    float iouThresh  = IOUThreshold.floatValue;
    int   limit      = boxesLimit.intValue;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSArray<NSNumber *> *> *raw =
            [model detectObjectsInImage:data
                           minimumScore:minScore
                           IOUThreshold:iouThresh
                             boxesLimit:limit];

        NSMutableArray<ResultObjectDetection *> *detections = [NSMutableArray new];
        for (NSArray<NSNumber *> *det in raw) {
            // det = [classIndex, score, left, top, right, bottom, width, height]
            if (det.count < 8) continue;
            PytorchRect *rect = [PytorchRect makeWithLeft:det[2]
                                                      top:det[3]
                                                    right:det[4]
                                                   bottom:det[5]
                                                    width:det[6]
                                                   height:det[7]];
            ResultObjectDetection *result =
                [ResultObjectDetection makeWithClassIndex:det[0]
                                               className:nil
                                                   score:det[1]
                                                    rect:rect];
            [detections addObject:result];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(detections, nil);
        });
    });
}

@end
