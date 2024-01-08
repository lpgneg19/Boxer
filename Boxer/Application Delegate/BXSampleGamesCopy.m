/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSampleGamesCopy.h"
#import "Boxer-Swift.h"

@implementation BXSampleGamesCopy

- (id) initFromSourceURL: (NSURL *)sourceURL toTargetURL: (NSURL *)targetURL
{
    return [self initWithSourceURL:sourceURL targetURL:targetURL];
}

- (instancetype) initWithSourceURL: (NSURL *)sourceURL targetURL: (NSURL *)targetURL
{
    self = [self init];
	if (self)
	{
        self.sourceURL = sourceURL;
        self.targetURL = targetURL;
	}
	return self;
}

- (void) main
{
	if (self.isCancelled) return;
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants;
	
    NSArray *gameURLs = [manager contentsOfDirectoryAtURL: self.sourceURL includingPropertiesForKeys: nil options: options error: NULL];
    for (NSURL *gameURL in gameURLs)
	{
		if (self.isCancelled) return;
		
        NSString *gameName = gameURL.lastPathComponent;
        NSURL *destinationURL = [self.targetURL URLByAppendingPathComponent: gameName];
        
        BOOL copied = [manager copyItemAtURL: gameURL toURL: destinationURL error: NULL];
        if (copied)
        {
            [destinationURL setResourceValue: @YES forKey: NSURLHasHiddenExtensionKey error: NULL];
        
            NSString *baseName = gameName.stringByDeletingPathExtension;
            NSURL *iconURL = [[NSBundle mainBundle] URLForResource: baseName
                                                     withExtension: @"jpg"
                                                      subdirectory: @"Sample Game Icons"];
        
            //Generate a cover art image from this icon (cheaper than storing a full icns file)
            if (iconURL)
            {
                NSImage *image = [[NSImage alloc] initWithContentsOfURL: iconURL];
                if (image)
                {
                    NSImage *iconForGame = [CoverArt coverArtWithImage: image];
                    
                    [[NSWorkspace sharedWorkspace] setIcon: iconForGame forFile: destinationURL.path options: NSExcludeQuickDrawElementsIconCreationOption];
                }
            }
        }
	}
}

@end
