#import <ImageIO/ImageIO.h>

#import "TileSheet.h"

static const int kTilesPerRow = 40;

NSSize NhPixelSizeOfImageFile(NSString * path)
{
	NSSize size = NSZeroSize;
	CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
	if ( source == NULL )
		return size;
	NSDictionary * properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
	CFRelease(source);
	size.width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue];
	size.height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
	return size;
}

NSSize NhTileSizeOfSheet(NSString * fileName, NSSize pixels)
{
	// the number must end the name, so "DawnHack 3.6.png" isn't read as 6px tiles
	NSRegularExpression * re = [NSRegularExpression regularExpressionWithPattern:@"(?:^|[^0-9.])([0-9]+)(?:x([0-9]+))?\\.[a-z]+$"
		options:NSRegularExpressionCaseInsensitive error:NULL];
	NSString * name = [fileName lastPathComponent];
	NSTextCheckingResult * match = [re firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
	int width = (int)pixels.width;
	int rowWidth = width >= kTilesPerRow && width % kTilesPerRow == 0 ? width / kTilesPerRow : 0;
	if ( match ) {
		int w = [[name substringWithRange:[match rangeAtIndex:1]] intValue];
		NSRange hRange = [match rangeAtIndex:2];
		int h = hRange.location == NSNotFound ? w : [[name substringWithRange:hRange] intValue];
		// a sheet 40 tiles wide only trusts a name that agrees, so "tiles64 copy 2.png" isn't read as 2px tiles
		if ( w > 0 && h > 0 && width % w == 0 && (rowWidth == 0 || w == rowWidth) )
			return NSMakeSize(w, h);
	}
	if ( rowWidth )
		return NSMakeSize(rowWidth, rowWidth);
	return NSZeroSize;
}

NSString * NhTileSheetProblem(NSSize pixels, NSSize tileSize, int tilesNeeded)
{
	if ( pixels.width <= 0 || pixels.height <= 0 )
		return @"It isn't an image that can be read.";
	if ( tileSize.width <= 0 || tileSize.height <= 0 )
		return @"The tile size couldn't be worked out. Put it at the end of the file name, e.g. tiles32.png or tiles10x20.png.";
	int tiles = (int)(pixels.width / tileSize.width) * (int)(pixels.height / tileSize.height);
	if ( tiles < tilesNeeded )
		return [NSString stringWithFormat:@"It has %d tiles of %dx%d pixels, but this version of NetHack needs %d. It was probably made for an older version.",
			tiles, (int)tileSize.width, (int)tileSize.height, tilesNeeded];
	return nil;
}

NSArray<NSString *> * NhTileSheetsInFolder(NSString * folder)
{
	NSFileManager * fm = [NSFileManager defaultManager];
	NSMutableArray * sheets = [NSMutableArray array];
	for ( NSString * name in [fm contentsOfDirectoryAtPath:folder error:NULL] ) {
		NSString * ext = [[name pathExtension] lowercaseString];
		if ( [name hasPrefix:@"."] || !([ext isEqualToString:@"png"] || [ext isEqualToString:@"bmp"]) )
			continue;
		BOOL isFolder = NO;
		if ( [fm fileExistsAtPath:[folder stringByAppendingPathComponent:name] isDirectory:&isFolder] && !isFolder )
			[sheets addObject:name];
	}
	return [sheets sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
}
