//
//  ImageUtils.m
//  LogoDetector
//
//  Created By Yongyang Nie 11/20/2016
//  Copyright (c) 2016 Yongyang Nie. All rights reserved.
//  License:
//  You may not copy, redistribute, use without quoting the author.
//  By using this file, you agree to the following LICENSE:
//  https://creativecommons.org/licenses/by-nc-nd/4.0/legalcode

#import "ImageUtils.h"
#import "MSERManager.h"

//http://docs.opencv.org/doc/tutorials/ios/image_manipulation/image_manipulation.html

@implementation ImageUtils

const cv::Scalar RED = cv::Scalar(0, 0, 255);
const cv::Scalar GREEN = cv::Scalar(0, 255, 0);
const cv::Scalar BLUE = cv::Scalar(255, 0, 0);
const cv::Scalar BLACK = cv::Scalar(0, 0, 0);
const cv::Scalar WHITE = cv::Scalar(255, 255, 255);
const cv::Scalar YELLOW = cv::Scalar(0, 255, 255);
const cv::Scalar LIGHT_GRAY = cv::Scalar(100, 100, 100);

+ (cv::Mat) cvMatFromUIImage: (UIImage *) image{
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+ (cv::Mat) cvMatGrayFromUIImage: (UIImage *)image{
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+ (UIImage *) UIImageFromCVMat: (cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1)
    {
        colorSpace = CGColorSpaceCreateDeviceGray();
    }
    else
    {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,//bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

+ (cv::Mat) mserToMat: (std::vector<cv::Point> *) mser
{
    int minX = std::min_element(mser->begin(), mser->end(), [] (cv::Point &p1, cv::Point &p2) { return p1.x < p2.x; })[0].x;
    int minY = std::min_element(mser->begin(), mser->end(), [] (cv::Point &p1, cv::Point &p2) { return p1.y < p2.y; })[0].y;
    int maxX = std::max_element(mser->begin(), mser->end(), [] (cv::Point &p1, cv::Point &p2) { return p1.x < p2.x; })[0].x;
    int maxY = std::max_element(mser->begin(), mser->end(), [] (cv::Point &p1, cv::Point &p2) { return p1.y < p2.y; })[0].y;
    
    cv::Mat color(maxY - minY, maxX - minX, CV_8UC3);
    
    std::for_each(mser->begin(), mser->end(), [&] (cv::Point &p)
                  {
                      cv::Point newPoint = cv::Point(p.x - minX, p.y - minY);
                      cv::line(color, newPoint, newPoint, WHITE);
                  });
    cv::Mat gray;
    cvtColor(color, gray, CV_BGRA2GRAY);
    
    return gray;
}

+ (void) drawMser: (std::vector<cv::Point> *) mser intoImage: (cv::Mat *) image withColor: (cv::Scalar) color
{
    std::for_each(mser->begin(), mser->end(), [&](cv::Point &p) {
        cv::line(*image, p, p, color);
    });
}

+ (std::vector<cv::Point>) maxMser: (cv::Mat *) gray
{
    std::vector<std::vector<cv::Point>> msers;
    [[MSERManager sharedInstance] detectRegions: *gray intoVector: msers];
    
    if (msers.size() == 0) return std::vector<cv::Point>();
    
    std::vector<cv::Point> mser =
    std::max_element(msers.begin(), msers.end(), [] (std::vector<cv::Point> &m1, std::vector<cv::Point> &m2) {
        return m1.size() < m2.size();
    })[0];
    
    return mser;
}

+(UIImage*) imageWithMat:(const cv::Mat&) image andDeviceOrientation: (UIDeviceOrientation) orientation
{
    UIImageOrientation imgOrientation = UIImageOrientationUp;
    
    switch (orientation){
        case UIDeviceOrientationLandscapeLeft:
            imgOrientation = UIImageOrientationUp; break;
            
        case UIDeviceOrientationLandscapeRight:
            imgOrientation = UIImageOrientationDown; break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            imgOrientation = UIImageOrientationRightMirrored; break;
            
        default:
        case UIDeviceOrientationPortrait:
            imgOrientation = UIImageOrientationRight; break;
    };
    
    return [ImageUtils imageWithMat:image andImageOrientation:imgOrientation];
}

+(UIImage*) imageWithMat:(const cv::Mat&) image andImageOrientation: (UIImageOrientation) orientation;
{
    cv::Mat rgbaView;
    
    if (image.channels() == 3)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_BGR2RGBA);
    }
    else if (image.channels() == 4)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_BGRA2RGBA);
    }
    else if (image.channels() == 1)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_GRAY2RGBA);
    }
    
    NSData *data = [NSData dataWithBytes:rgbaView.data length:rgbaView.elemSize() * rgbaView.total()];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGBitmapInfo bmInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(rgbaView.cols,                              //width
                                        rgbaView.rows,                              //height
                                        8,                                          //bits per component
                                        8 * rgbaView.elemSize(),                    //bits per pixel
                                        rgbaView.step.p[0],                         //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        bmInfo,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef scale:1 orientation:orientation];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end
