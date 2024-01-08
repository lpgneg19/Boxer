//
//  NSBezierPath+MCAdditions.m
//
//  Created by Sean Patrick O'Brien on 4/1/08.
//  Copyright 2008 MolokoCacao. All rights reserved.
//

#import "NSBezierPath+MCAdditions.h"

#ifndef MAC_OS_VERSION_14_0
#define MAC_OS_VERSION_14_0 140000
#endif

static void CGPathCallback(void *info, const CGPathElement *element)
{
	NSBezierPath *path = (__bridge NSBezierPath *)info;
	CGPoint *points = element->points;
	
	switch (element->type) {
		case kCGPathElementMoveToPoint:
		{
			[path moveToPoint:NSMakePoint(points[0].x, points[0].y)];
			break;
		}
		case kCGPathElementAddLineToPoint:
		{
			[path lineToPoint:NSMakePoint(points[0].x, points[0].y)];
			break;
		}
		case kCGPathElementAddQuadCurveToPoint:
		{
			// NOTE: This is untested.
			NSPoint currentPoint = [path currentPoint];
			NSPoint interpolatedPoint = NSMakePoint((currentPoint.x + 2*points[0].x) / 3, (currentPoint.y + 2*points[0].y) / 3);
			[path curveToPoint:NSMakePoint(points[1].x, points[1].y) controlPoint1:interpolatedPoint controlPoint2:interpolatedPoint];
			break;
		}
		case kCGPathElementAddCurveToPoint:
		{
			[path curveToPoint:NSMakePoint(points[2].x, points[2].y) controlPoint1:NSMakePoint(points[0].x, points[0].y) controlPoint2:NSMakePoint(points[1].x, points[1].y)];
			break;
		}
		case kCGPathElementCloseSubpath:
		{
			[path closePath];
			break;
		}
	}
}

@implementation NSBezierPath (MCAdditions)

+ (NSBezierPath *)ourBezierPathWithCGPath:(CGPathRef)pathRef
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	CGPathApply(pathRef, (void *)path, CGPathCallback);
	
	return path;
}

// Method borrowed from Google's Cocoa additions
- (CGPathRef)createCGPath
{
	CGMutablePathRef thePath = CGPathCreateMutable();
	if (!thePath) return nil;
	
	NSInteger elementCount = [self elementCount];
	
	// The maximum number of points is 3 for a NSCurveToBezierPathElement.
	// (controlPoint1, controlPoint2, and endPoint)
	NSPoint controlPoints[3];
	NSInteger i;
	for (i = 0; i < elementCount; i++) {
		switch ([self elementAtIndex:i associatedPoints:controlPoints]) {
			case NSBezierPathElementMoveTo:
				CGPathMoveToPoint(thePath, &CGAffineTransformIdentity, 
								  controlPoints[0].x, controlPoints[0].y);
				break;
			case NSBezierPathElementLineTo:
				CGPathAddLineToPoint(thePath, &CGAffineTransformIdentity, 
									 controlPoints[0].x, controlPoints[0].y);
				break;
			case NSBezierPathElementCurveTo:
				CGPathAddCurveToPoint(thePath, &CGAffineTransformIdentity, 
									  controlPoints[0].x, controlPoints[0].y,
									  controlPoints[1].x, controlPoints[1].y,
									  controlPoints[2].x, controlPoints[2].y);
				break;
			case NSBezierPathElementClosePath:
				CGPathCloseSubpath(thePath);
				break;
			default:
				NSLog(@"Unknown element at [NSBezierPath (GTMBezierPathCGPathAdditions) cgPath]");
				break;
		};
	}
	return thePath;
}

- (NSBezierPath *)pathWithStrokeWidth:(CGFloat)strokeWidth
{
	NSBezierPath *path = [self copy];
	CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
	CGPathRef pathRef;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_VERSION_14_0
	if (@available(macOS 14.0, *)) @autoreleasepool {
		pathRef = path.CGPath;
		// match the old memory management.
		CFRetain(pathRef);
	} else {
		pathRef = [path createCGPath];
	}
#else
	pathRef = [path createCGPath];
#endif
	
	CGContextSaveGState(context);
		
	CGContextBeginPath(context);
	CGContextAddPath(context, pathRef);
	CGContextSetLineWidth(context, strokeWidth);
	CGContextReplacePathWithStrokedPath(context);
	CGPathRef strokedPathRef = CGContextCopyPath(context);
	CGContextBeginPath(context);
	NSBezierPath *strokedPath;
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_VERSION_14_0
	if (@available(macOS 14.0, *)) {
		strokedPath = [NSBezierPath bezierPathWithCGPath:strokedPathRef];
	} else {
		strokedPath = [NSBezierPath ourBezierPathWithCGPath:strokedPathRef];
	}
#else
	strokedPath = [NSBezierPath ourBezierPathWithCGPath:strokedPathRef];
#endif
	
	CGContextRestoreGState(context);
	
	CFRelease(pathRef);
	CFRelease(strokedPathRef);
	
	return strokedPath;
}

- (void)fillWithInnerShadow:(NSShadow *)innerShadow
{
	[NSGraphicsContext saveGraphicsState];
	
	NSSize offset = innerShadow.shadowOffset;
	NSSize originalOffset = offset;
	CGFloat radius = innerShadow.shadowBlurRadius;
	NSRect bounds = NSInsetRect(self.bounds, -(ABS(offset.width) + radius), -(ABS(offset.height) + radius));
	offset.height += bounds.size.height;
	innerShadow.shadowOffset = offset;
	NSAffineTransform *transform = [NSAffineTransform transform];
	if ([[NSGraphicsContext currentContext] isFlipped])
		[transform translateXBy:0 yBy:bounds.size.height];
	else
		[transform translateXBy:0 yBy:-bounds.size.height];
	
	NSBezierPath *drawingPath = [NSBezierPath bezierPathWithRect:bounds];
	[drawingPath setWindingRule:NSEvenOddWindingRule];
	[drawingPath appendBezierPath:self];
	[drawingPath transformUsingAffineTransform:transform];
	
	[self addClip];
	[innerShadow set];
	[[NSColor blackColor] set];
	[drawingPath fill];
	
	innerShadow.shadowOffset = originalOffset;
	
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawBlurWithColor:(NSColor *)color radius:(CGFloat)radius
{
	NSRect bounds = NSInsetRect(self.bounds, -radius, -radius);
	NSShadow *blurShadow = [[NSShadow alloc] init];
	blurShadow.shadowOffset = NSMakeSize(0, bounds.size.height);
	blurShadow.shadowBlurRadius = radius;
	blurShadow.shadowColor = color;
	NSBezierPath *path = [self copy];
	NSAffineTransform *transform = [NSAffineTransform transform];
	if ([[NSGraphicsContext currentContext] isFlipped])
		[transform translateXBy:0 yBy:bounds.size.height];
	else
		[transform translateXBy:0 yBy:-bounds.size.height];
	[path transformUsingAffineTransform:transform];
	
	[NSGraphicsContext saveGraphicsState];
	
	[blurShadow set];
	[[NSColor blackColor] set];
	NSRectClip(bounds);
	[path fill];
	
	[NSGraphicsContext restoreGraphicsState];
}

// Credit for the next two methods goes to Matt Gemmell
- (void)strokeInside
{
    /* Stroke within path using no additional clipping rectangle. */
    [self strokeInsideWithinRect:NSZeroRect];
}

- (void)strokeInsideWithinRect:(NSRect)clipRect
{
    NSGraphicsContext *thisContext = [NSGraphicsContext currentContext];
    CGFloat lineWidth = [self lineWidth];
    
    /* Save the current graphics context. */
    [thisContext saveGraphicsState];
    
    /* Double the stroke width, since -stroke centers strokes on paths. */
    [self setLineWidth:(lineWidth * 2.0f)];
    
    /* Clip drawing to this path; draw nothing outwith the path. */
    [self setClip];
    
    /* Further clip drawing to clipRect, usually the view's frame. */
    if (clipRect.size.width > 0.0 && clipRect.size.height > 0.0) {
        [NSBezierPath clipRect:clipRect];
    }
    
    /* Stroke the path. */
    [self stroke];
    
    /* Restore the previous graphics context. */
    [thisContext restoreGraphicsState];
    [self setLineWidth:lineWidth];
}

@end
