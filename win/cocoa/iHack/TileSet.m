//
//  TileSet.m
//  SlashEM
//
//  Created by dirk on 1/17/10.
//  Copyright 2010 Dirk Zimmermann. All rights reserved.
//

/*
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation, version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "TileSet.h"
#import <AppKit/AppKit.h>
#include "hack.h"

extern glyph_map glyphmap[MAX_GLYPH];

static TileSet *s_instance = nil;

@implementation TileSet

@synthesize image;
@synthesize	tileSize;
@synthesize	displaySize;

+ (TileSet *)instance {
	return s_instance;
}

+ (void)setInstance:(TileSet *)ts {
	s_instance = ts;
}

+ (CGImageRef)largestCGImageOfImage:(NSImage *)img {
	NSBitmapImageRep *best = nil;
	for (NSImageRep *rep in img.representations) {
		if ([rep isKindOfClass:[NSBitmapImageRep class]] && rep.pixelsWide > best.pixelsWide)
			best = (NSBitmapImageRep *)rep;
	}
	if (best)
		return best.CGImage;
	return [img CGImageForProposedRect:NULL context:nil hints:nil];
}

+ (NSSize)pixelSizeOfImage:(NSImage *)img {
	CGImageRef cg = [self largestCGImageOfImage:img];
	if (cg == NULL)
		return img.size;
	return NSMakeSize(CGImageGetWidth(cg), CGImageGetHeight(cg));
}

- (id)initWithImage:(NSImage *)img tileSize:(NSSize)ts {
	if (self = [super init]) {
		// one image point per sheet pixel, regardless of the file's DPI
		CGImageRef cg = [TileSet largestCGImageOfImage:img];
		if (cg) {
			image = [[NSImage alloc] initWithCGImage:cg size:[TileSet pixelSizeOfImage:img]];
		} else {
			image = img;
		}
		tileSize = ts;
		rows = image.size.height / tileSize.height;
		columns = image.size.width / tileSize.width;

		// tiles larger than 16px are shown at the size of 16px tiles, with the extra pixels used for sharpness
		CGFloat m = tileSize.width > tileSize.height ? tileSize.width : tileSize.height;
		CGFloat scale = m > 16.0 ? 16.0 / m : 1.0;
		displaySize = NSMakeSize(tileSize.width * scale, tileSize.height * scale);
	}
	return self;
}

- (NSRect)sourceRectForGlyph:(int)glyph {
	int tile = glyphmap[glyph].tileidx;
	return [self sourceRectForTile:tile];
}

- (NSRect)sourceRectForTile:(int)tile {
	int col = tile % columns;
	// measured from the top: sheets need not be an exact multiple of the tile height
	NSRect r = { col * tileSize.width, image.size.height - (tile/columns + 1) * tileSize.height };
	r.size = tileSize;
	return r;
}

- (NSSize)imageSize
{
	return displaySize;
}

- (NSImage *)imageForGlyph:(int)glyph enabled:(BOOL)enabled
{
	// get image
	NSRect srcRect = [self sourceRectForGlyph:glyph];
	NSSize size = [self imageSize];
	NSImage * newImage = [[NSImage alloc] initWithSize:size];
	NSRect dstRect = NSMakeRect(0, 0, size.width, size.height);
	[newImage lockFocus];
	if (tileSize.width > size.width)
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationMedium];
	[image drawInRect:dstRect fromRect:srcRect operation:NSCompositingOperationCopy fraction:enabled ? 1.0f : 0.5];
	[newImage unlockFocus];
	return newImage;
}

@end
