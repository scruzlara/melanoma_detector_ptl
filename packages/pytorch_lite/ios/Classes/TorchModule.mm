// TorchModule.mm — ObjC++ bridge to LibTorch mobile.
#import "TorchModule.h"
#import <UIKit/UIKit.h>
#include <LibTorch-Lite-Nightly/LibTorch-Lite.h>
#include <vector>
#include <algorithm>
#include <stdexcept>

using namespace std;

// ---------------------------------------------------------------------------
// Private implementation
// ---------------------------------------------------------------------------

@implementation TorchModule {
    torch::jit::mobile::Module *_modulePtr;
}

@synthesize imageWidth  = _imageWidth;
@synthesize imageHeight = _imageHeight;
@synthesize numberOfClasses = _numberOfClasses;

- (void)dealloc {
    delete _modulePtr;
    _modulePtr = nullptr;
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------

+ (nullable TorchModule *)moduleAtPath:(NSString *)filePath
                            imageWidth:(int)imageWidth
                           imageHeight:(int)imageHeight
                       numberOfClasses:(int)numberOfClasses
                                 error:(NSError *_Nullable *_Nullable)outError {
    // Verify file exists before attempting LibTorch load
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSString *msg = [NSString stringWithFormat:@"File not found: %@", filePath];
        NSLog(@"[TorchModule] %@", msg);
        if (outError) {
            *outError = [NSError errorWithDomain:@"TorchModule" code:-2
                                       userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }

    TorchModule *m = [TorchModule new];
    m->_imageWidth       = imageWidth  > 0 ? imageWidth  : 224;
    m->_imageHeight      = imageHeight > 0 ? imageHeight : 224;
    m->_numberOfClasses  = numberOfClasses;
    try {
        m->_modulePtr = new torch::jit::mobile::Module(
            torch::jit::_load_for_mobile(filePath.UTF8String)
        );
        return m;
    } catch (const exception& e) {
        NSString *msg = [NSString stringWithUTF8String:e.what()];
        NSLog(@"[TorchModule] Failed to load '%@': %@", filePath, msg);
        if (outError) {
            *outError = [NSError errorWithDomain:@"TorchModule" code:-1
                                       userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    }
}

// ---------------------------------------------------------------------------
// Image → float tensor helper
// ---------------------------------------------------------------------------

/**
 Decodes imageData, resizes to (targetW x targetH), and returns a CHW float
 tensor normalised with the supplied mean/std.  The returned vector has size
 3 * targetW * targetH (R plane, G plane, B plane in row-major order).
*/
- (vector<float>)_floatTensorFromImageData:(NSData *)imageData
                                      mean:(NSArray<NSNumber *> *)mean
                                       std:(NSArray<NSNumber *> *)std {
    int targetW = _imageWidth;
    int targetH = _imageHeight;

    UIImage *image = [UIImage imageWithData:imageData];
    if (!image) return {};

    // Resize
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(targetW, targetH), YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetW, targetH)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!resized) return {};

    // Decode to RGBX (no alpha, 4 bytes/pixel)
    vector<uint8_t> raw(targetW * targetH * 4);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        raw.data(), targetW, targetH, 8, targetW * 4, cs,
        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big
    );
    CGColorSpaceRelease(cs);
    if (!ctx) return {};
    CGContextDrawImage(ctx, CGRectMake(0, 0, targetW, targetH), resized.CGImage);
    CGContextRelease(ctx);

    float mR = mean.count > 0 ? mean[0].floatValue : 0.485f;
    float mG = mean.count > 1 ? mean[1].floatValue : 0.456f;
    float mB = mean.count > 2 ? mean[2].floatValue : 0.406f;
    float sR = std.count  > 0 ? std[0].floatValue  : 0.229f;
    float sG = std.count  > 1 ? std[1].floatValue  : 0.224f;
    float sB = std.count  > 2 ? std[2].floatValue  : 0.225f;

    int n = targetW * targetH;
    vector<float> tensor(3 * n);
    for (int i = 0; i < n; i++) {
        tensor[i]       = (raw[i * 4 + 0] / 255.0f - mR) / sR; // R plane
        tensor[n + i]   = (raw[i * 4 + 1] / 255.0f - mG) / sG; // G plane
        tensor[2*n + i] = (raw[i * 4 + 2] / 255.0f - mB) / sB; // B plane
    }
    return tensor;
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

- (nullable NSArray<NSNumber *> *)predictImage:(NSData *)imageData
                                          mean:(NSArray<NSNumber *> *)mean
                                           std:(NSArray<NSNumber *> *)std {
    if (!_modulePtr) return nil;

    auto floatInput = [self _floatTensorFromImageData:imageData mean:mean std:std];
    if (floatInput.empty()) return nil;

    int W = _imageWidth, H = _imageHeight;
    try {
        auto input = torch::from_blob(floatInput.data(), {1, 3, H, W}, torch::kFloat32).clone();
        auto output = _modulePtr->forward({input}).toTensor();
        auto data   = output.data_ptr<float>();
        int64_t n   = output.numel();

        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:(NSUInteger)n];
        for (int64_t i = 0; i < n; i++) {
            [result addObject:@(data[i])];
        }
        return result;
    } catch (const exception& e) {
        NSLog(@"[TorchModule] Classification error: %s", e.what());
        return nil;
    }
}

// ---------------------------------------------------------------------------
// Object detection
// ---------------------------------------------------------------------------

static float _iou(float ax1, float ay1, float ax2, float ay2,
                  float bx1, float by1, float bx2, float by2) {
    float ix1 = max(ax1, bx1), iy1 = max(ay1, by1);
    float ix2 = min(ax2, bx2), iy2 = min(ay2, by2);
    float inter = max(0.0f, ix2 - ix1) * max(0.0f, iy2 - iy1);
    float aArea = (ax2 - ax1) * (ay2 - ay1);
    float bArea = (bx2 - bx1) * (by2 - by1);
    float uni   = aArea + bArea - inter;
    return uni <= 0 ? 0 : inter / uni;
}

- (NSArray<NSArray<NSNumber *> *> *)detectObjectsInImage:(NSData *)imageData
                                            minimumScore:(float)minimumScore
                                            IOUThreshold:(float)IOUThreshold
                                              boxesLimit:(int)boxesLimit {
    if (!_modulePtr) return @[];

    // YOLO models are usually normalised in [0,1] without ImageNet mean/std
    auto floatInput = [self _floatTensorFromImageData:imageData
                                                 mean:@[@(0.0), @(0.0), @(0.0)]
                                                  std:@[@(1.0), @(1.0), @(1.0)]];
    if (floatInput.empty()) return @[];

    int W = _imageWidth, H = _imageHeight;
    try {
        auto input  = torch::from_blob(floatInput.data(), {1, 3, H, W}, torch::kFloat32).clone();
        auto output = _modulePtr->forward({input});

        torch::Tensor outT;
        if (output.isTensor()) {
            outT = output.toTensor().squeeze(0); // [N, 5+C]
        } else {
            return @[];
        }

        int64_t numPreds = outT.size(0);
        int64_t predSize = outT.size(1);
        int     numC     = _numberOfClasses > 0 ? _numberOfClasses : (int)(predSize - 5);
        auto    data     = outT.data_ptr<float>();

        struct Det { float x1, y1, x2, y2, score; int cls; };
        vector<Det> dets;

        for (int64_t i = 0; i < numPreds; i++) {
            float conf = data[i * predSize + 4];
            if (conf < minimumScore) continue;

            int   bestCls   = 0;
            float bestScore = 0;
            for (int c = 0; c < max(numC, 1); c++) {
                float s = (numC > 0) ? data[i * predSize + 5 + c] * conf : conf;
                if (s > bestScore) { bestScore = s; bestCls = c; }
            }
            if (bestScore < minimumScore) continue;

            float cx = data[i * predSize + 0];
            float cy = data[i * predSize + 1];
            float bw = data[i * predSize + 2];
            float bh = data[i * predSize + 3];
            dets.push_back({cx - bw/2, cy - bh/2, cx + bw/2, cy + bh/2, bestScore, bestCls});
        }

        sort(dets.begin(), dets.end(), [](const Det& a, const Det& b){ return a.score > b.score; });

        vector<bool> suppressed(dets.size(), false);
        NSMutableArray *result = [NSMutableArray new];

        for (size_t i = 0; i < dets.size() && (int)result.count < boxesLimit; i++) {
            if (suppressed[i]) continue;
            const Det& d = dets[i];
            float left   = max(0.0f, d.x1);
            float top    = max(0.0f, d.y1);
            float right  = min(1.0f, d.x2);
            float bottom = min(1.0f, d.y2);
            [result addObject:@[@(d.cls), @(d.score),
                                @(left), @(top), @(right), @(bottom),
                                @(right - left), @(bottom - top)]];
            for (size_t j = i + 1; j < dets.size(); j++) {
                if (!suppressed[j] && dets[j].cls == d.cls &&
                    _iou(d.x1, d.y1, d.x2, d.y2,
                         dets[j].x1, dets[j].y1, dets[j].x2, dets[j].y2) > IOUThreshold) {
                    suppressed[j] = true;
                }
            }
        }
        return result;
    } catch (const exception& e) {
        NSLog(@"[TorchModule] Detection error: %s", e.what());
        return @[];
    }
}

// ---------------------------------------------------------------------------
// Custom tensor inference
// ---------------------------------------------------------------------------

- (nullable NSArray<NSNumber *> *)predictCustomInput:(NSArray<NSNumber *> *)input
                                               shape:(NSArray<NSNumber *> *)shape
                                               dtype:(NSString *)dtype {
    if (!_modulePtr) return nil;

    vector<float> floatInput;
    floatInput.reserve(input.count);
    for (NSNumber *n in input) {
        floatInput.push_back(n.floatValue);
    }

    vector<int64_t> tensorShape;
    tensorShape.reserve(shape.count);
    for (NSNumber *n in shape) {
        tensorShape.push_back(n.longLongValue);
    }

    try {
        auto tensor = torch::from_blob(floatInput.data(), tensorShape, torch::kFloat32).clone();
        auto output = _modulePtr->forward({tensor}).toTensor();
        auto data   = output.data_ptr<float>();
        int64_t n   = output.numel();

        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:(NSUInteger)n];
        for (int64_t i = 0; i < n; i++) {
            [result addObject:@(data[i])];
        }
        return result;
    } catch (const exception& e) {
        NSLog(@"[TorchModule] Custom prediction error: %s", e.what());
        return nil;
    }
}

@end
