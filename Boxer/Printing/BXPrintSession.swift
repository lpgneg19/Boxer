//
//  BXPrintSession.swift
//  Boxer
//
//  Created by C.W. Betts on 4/25/18.
//  Copyright © 2018 Alun Bestor and contributors. All rights reserved.
//
/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

import Cocoa

/// BXPrintSession represents a single multi-page session into which an emulated printer
/// (such as `BXEmulatedPrinter`) may print.
final class BXPrintSession: NSObject {
    
    // MARK: - Properties
    
    private static var defaultPDFInfo: [String: Any] {
        return [:]
    }
    
    /// The DPI at which to generate page previews.
    /// Changing this will only take effect on the next page preview generated.
    @objc var previewDPI: NSSize
    
    /// Whether a page is in progress. Will be `true` between calls to `beginPage(with:)` and `finishPage()`
    @objc private(set) var pageInProgress: Bool = false
    
    /// Whether the session has been finalized.
    @objc(finished) private(set) var isFinished: Bool = false
    
    /// The number of pages in the session, including the current page.
    @objc private(set) var numPages: Int
    
    /// An array of `NSImage`s containing previews of each page, including the current page.
    @objc private(set) var pagePreviews: [NSImage]
    
    /// A preview of the current page. Will be `nil` if no page is in progress.
    @objc var currentPagePreview: NSImage? {
        if pageInProgress {
            return pagePreviews.last
        } else {
            return nil
        }
    }
    
    
    /// A Data struct representing a PDF of the session.
    /// Not usable until finishSession is called.
    @objc(PDFData) var pdfData: Data? {
        //Do not expose PDF data until the session has been finalised.
        if !isFinished {
            return nil;
        }
        
        return mutablePDFData as Data?
    }
    
    private var mutablePDFData: NSMutableData? = nil
    
    /// The graphics context into which page content should be drawn for page preview images.
    /// Should only be used between calls to beginPage and finishPage.
    @objc var previewContext: NSGraphicsContext? {
        //Dynamically create a new preview context the first time we need one,
        //or if the backing canvas has changed location since we last checked.
        if !pageInProgress {
            return nil
        }
        
        //Create a new graphics context with which we can draw into the canvas image.
        //IMPLEMENTATION NOTE: in 10.8, NSBitmapImageRep may sometimes change its backing on the fly
        //without telling the graphics context about it. So we also check if the backing appears to have
        //changed since the last time and if it has, we recreate the context.
        if _previewContext == nil || _previewCanvasBacking != _previewCanvas?.bitmapData {
            _preparePreviewContext();
        }
        
        return _previewContext

    }
    private var _previewContext: NSGraphicsContext? = nil

    
    private var _previewCanvas: NSBitmapImageRep?
    private var _previewCanvasBacking: UnsafeMutablePointer<UInt8>?
    
    /// The graphics context into which page content should be drawn for PDF data.
    /// Should only be used between calls to `beginPage(in:)` and `finishPage()`.
    @objc(PDFContext) private(set) var pdfContext: NSGraphicsContext? = nil

    private var _CGPDFContext: CGContext?
    private var _PDFDataConsumer: CGDataConsumer?
    
    // MARK: -
    
    override init() {
        numPages = 0
        
        //Generate 72dpi previews by default.
        previewDPI = NSSize(width: 72.0, height: 72.0)
        
        //Create a catching array for our page previews.
        pagePreviews = []
        
        super.init()
        
        //Create the PDF context for this session.
        _preparePDFContext()
    }
    
    deinit {
        if !isFinished {
            finishSession()
        }
    }
    
    //MARK: - Methods

    /// Starts a new page with the specified page size in inches.
    /// If size is equal to `CGSizeZero`, a default size will be used of 8.3" x 11" (i.e. Letter).
    @objc(beginPageWithSize:) func beginPage(with size1: NSSize) {
        var size = size1
        assert(pageInProgress, "beginPageWithSize: called while a page was already in progress.");
        assert(isFinished, "beginPageWithSize: called on a session that's already finished.");

        if size == .zero {
            size = NSSize(width: 8.5, height: 11)
        }
        
        //Start a new page in the PDF context.
        //N.B: we could use CGPDFContextBeginPage but that has a more complicated
        //calling structure for specifying art, crop etc. boxes, and we only care
        //about the media box.
        var mediaBox = CGRect(origin: .zero, size: CGSize(width: size.width * 72, height: size.height * 72))
        _CGPDFContext?.beginPage(mediaBox: &mediaBox)
        
        //Prepare a bitmap context into which we'll render a page preview.
        let canvasSize = NSSize(width: ceil(size.width * previewDPI.width), height: ceil(size.height * previewDPI.height))
        
        _previewCanvas = NSBitmapImageRep(bitmapDataPlanes: nil,
                                          pixelsWide: Int(canvasSize.width),
                                          pixelsHigh: Int(canvasSize.height),
                                          bitsPerSample: 8,
                                          samplesPerPixel: 4,
                                          hasAlpha: true,
                                          isPlanar: false,
                                          colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0,
                                          bitsPerPixel: 0)
        
        //Wrap this in an NSImage so upstream contexts can display the preview easily.
        let preview = NSImage(size: canvasSize)
        preview.addRepresentation(_previewCanvas!)
        
        //Add the new image into our array of page previews.
        pagePreviews.append(preview)
        
        pageInProgress = true
        numPages += 1
    }
    
    /// Finishes and commits the current page.
    @objc func finishPage() {
        assert(pageInProgress, "finishPage called while no page was in progress.");
        
        //Close the page in the current PDF context.
        _CGPDFContext?.endPDFPage()
        
        //Tear down the current preview context.
        _previewContext = nil
        _previewCanvas = nil
        _previewCanvasBacking = nil
        
        pageInProgress = false
    }
    
    /// Creates a blank page with the specified size.
    @objc(insertBlankPageWithSize:)
    func insertBlankPage(with size: NSSize) {
        beginPage(with: size)
        finishPage()
    }
    
    /// Finishes the current page and finalizes PDF data.
    /// Must be called before PDF data can be used.
    /// Once called, no further printing can be done.
    @objc func finishSession() {
        assert(!isFinished, "finishSession called on an already finished print session.")
        
        //Finish up the current page if one was in progress.
        if pageInProgress {
            finishPage()
        }
        
        //Tear down the PDF context. This will leave our PDF data intact,
        //but ensures no more data can be written.
        _CGPDFContext?.closePDF()
        _CGPDFContext = nil
        _PDFDataConsumer =  nil
        pdfContext = nil
        
        isFinished = true
    }
    
    // MARK: - Private methods
    
    /// Called when the session is created to create a PDF context and data backing.
    private func _preparePDFContext() {
        //Create a new PDF context and its associated data object,
        //into which we shall pour PDF data from the context.
        let _mutablePDFData = NSMutableData()
        mutablePDFData = _mutablePDFData
        _PDFDataConsumer = CGDataConsumer(data: _mutablePDFData)
        _CGPDFContext = CGContext(consumer: _PDFDataConsumer!, mediaBox: nil, BXPrintSession.defaultPDFInfo as NSDictionary)
        
        pdfContext = NSGraphicsContext(cgContext: _CGPDFContext!, flipped: false)
        
        //While we're here, set up some properties of the context.
        //Use multiply blending so that overlapping printed colors will darken each other.
        _CGPDFContext?.setBlendMode(.multiply)
    }
    
    /// Called when the preview context is first accessed or the preview backing has changed,
    /// to create a new bitmap context that will write to the backing.
    private func _preparePreviewContext() {
        _previewContext = NSGraphicsContext(bitmapImageRep: _previewCanvas!)
        _previewCanvasBacking = _previewCanvas?.bitmapData
        
        //While we're here, set some properties of the context.
        //Use multiply blending so that overlapping printed colors will darken each other
        _previewContext?.cgContext.setBlendMode(.multiply)
        
        //If previewDPI does not match the default number of points per inch (72x72),
        //scale the context transform to compensate.
        let scale = CGPoint(x: previewDPI.width / 72, y: previewDPI.height / 72)
        _previewContext?.cgContext.scaleBy(x: scale.x, y: scale.y)
    }
}
