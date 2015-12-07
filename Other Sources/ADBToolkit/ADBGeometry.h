/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

//ADBGeometry provides various functions for manipulating NSPoints, NSSizes and NSRects.

//The C brace is needed when including this header from an Objective C++ file
#if __cplusplus
extern "C" {
#endif

	#import <Foundation/Foundation.h>

	/// Returns the nearest power of two that can accommodate the specified value
	NSInteger fitToPowerOfTwo(NSInteger value);
    
    /// Returns whether the specified unsigned number is a power of two.
    BOOL isPowerOfTwo(NSUInteger value);

	/// Returns the aspect ratio (width / height) for size. This will be \c 0 if either dimension was <code>0</code>.
	CGFloat aspectRatioOfSize(NSSize size);
	
	/// Returns the specified size scaled to match the specified aspect ratio, preserving either width or height.
	/// Will return \c NSZeroSize if the aspect ratio is 0.
	NSSize sizeToMatchRatio(NSSize size, CGFloat aspectRatio, BOOL preserveHeight);

    /// Returns the specified point with \c x and \c y snapped to the nearest integral values.
    NSPoint integralPoint(NSPoint point);
        
	/// Returns the specified size with width and height rounded up to the nearest integral values.<br>
	/// Equivalent to <code>NSIntegralRect</code>. Will return \c NSZeroSize if width or height are 0 or negative.
	NSSize integralSize(NSSize size);

	/// Returns whether the inner size is equal to or less than the outer size.<br>
	/// An analogue for <code>NSContainsRect</code>.
	BOOL sizeFitsWithinSize(NSSize innerSize, NSSize outerSize);

	/// Returns \c innerSize scaled to fit exactly within \c outerSize while preserving aspect ratio.
	NSSize sizeToFitSize(NSSize innerSize, NSSize outerSize);

	/// Same as <code>sizeToFitSize</code>, but will return \c innerSize without scaling up if
    /// it already fits within <code>outerSize</code>.
	NSSize constrainToFitSize(NSSize innerSize, NSSize outerSize);

	/// Resize an \c NSRect to the target <code>NSSize</code>, using a relative anchor point:
	/// \c {0,0} is bottom left, \c {1,1} is top right, \c {0.5,0.5} is center.
	NSRect resizeRectFromPoint(NSRect theRect, NSSize newSize, NSPoint anchor);

	/// Get the relative position (<code>{0,0}</code>, <code>{1,1}</code> etc.) of an \c NSPoint origin, relative to the specified <code>NSRect</code>.
	NSPoint pointRelativeToRect(NSPoint thePoint, NSRect theRect);

	/// Align innerRect within outerRect relative to the specified anchor point:
	/// \c {0,0} is bottom left, \c {1,1} is top right, \c {0.5,0.5} is center.
	NSRect alignInRectWithAnchor(NSRect innerRect, NSRect outerRect, NSPoint anchor);

	/// Center \c innerRect within <code>outerRect</code>. Equivalent to \c alignRectInRectWithAnchor of <code>{0.5, 0.5}</code>.
	NSRect centerInRect(NSRect innerRect, NSRect outerRect);
		
	/// Proportionally resize \c innerRect to fit inside <code>outerRect</code>, relative to the specified anchor point.
	NSRect fitInRect(NSRect innerRect, NSRect outerRect, NSPoint anchor);
	
	/// Same as <code>fitInRect</code>, but will return \c alignInRectWithAnchor instead if \c innerRect already fits within <code>outerRect</code>.
	NSRect constrainToRect(NSRect innerRect, NSRect outerRect, NSPoint anchor);
	
	
	/// Clamp the specified point so that it fits within the specified rect.
	NSPoint clampPointToRect(NSPoint point, NSRect rect);
	
	/// Calculate the delta between two points.
	NSPoint deltaFromPointToPoint(NSPoint pointA, NSPoint pointB);
	
	/// Add/remove the specified delta from the specified starting point.
	NSPoint pointWithDelta(NSPoint point, NSPoint delta);
	NSPoint pointWithoutDelta(NSPoint point, NSPoint delta);

    
	
	// CG implementations of the above functions.
	BOOL CGSizeFitsWithinSize(CGSize innerSize, CGSize outerSize);
	
	CGSize CGSizeToFitSize(CGSize innerSize, CGSize outerSize);
    
    /// Returns the specified point with x and y snapped to the nearest integral values.
    CGPoint CGPointIntegral(CGPoint point);
    
	/// Returns the specified size with width and height rounded up to the nearest integral values.
	/// Equivalent to CGRectIntegral. Will return \c CGSizeZero if width or height are 0 or negative.
	CGSize CGSizeIntegral(CGSize size);
    
    #pragma mark -
    #pragma mark Debug logging
        
    #ifndef NSStringFromCGRect
    #define NSStringFromCGRect(rect) NSStringFromRect(NSRectFromCGRect(rect))
    #endif
        
    #ifndef NSStringFromCGSize
    #define NSStringFromCGSize(size) NSStringFromSize(NSSizeFromCGSize(size))
    #endif
        
    #ifndef NSStringFromCGPoint
    #define NSStringFromCGPoint(point) NSStringFromPoint(NSPointFromCGPoint(point))
    #endif
    
#if __cplusplus
} //Extern C
#endif
