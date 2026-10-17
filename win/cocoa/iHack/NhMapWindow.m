//
//  NhMapWindow.m
//  SlashEM
//
//  Created by dirk on 12/31/09.
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

#import "NhMapWindow.h"

#include "hack.h"

@implementation NhMapWindow

- (id) initWithType:(int)t {
	if (self = [super initWithType:t]) {
		NSLog(@"map window %lx", (long)self);
		memset(glyphs, kNoGlyph, sizeof glyphs);
		memset(bkglyphs, kNoGlyph, sizeof bkglyphs);
		memset(flags, 0, sizeof flags);
	}
	return self;
}

- (void) printGlyph:(int)glyph background:(int)bkglyph flags:(unsigned)f atX:(int)x y:(int)y {
	glyphs[y][x] = glyph;
	bkglyphs[y][x] = bkglyph;
	flags[y][x] = f;
}

- (void) setPeaceful:(BOOL)peaceful atX:(int)x y:(int)y {
	if ( peaceful )
		flags[y][x] |= kMapPeaceful;
	else
		flags[y][x] &= ~kMapPeaceful;
}

- (void)setCursX:(int)x y:(int)y {
	cursorX = x;
	cursorY = y;	
}

- (void)cursX:(int *)px y:(int *)py {
	*px = cursorX;
	*py = cursorY;
}



- (int) glyphAtX:(int)x y:(int)y {
	return glyphs[y][x];
}

- (int) backgroundGlyphAtX:(int)x y:(int)y {
	return bkglyphs[y][x];
}

- (unsigned) flagsAtX:(int)x y:(int)y {
	return flags[y][x];
}

- (void) clear {
	[super clear];
	memset(glyphs, kNoGlyph, sizeof glyphs);
	memset(bkglyphs, kNoGlyph, sizeof bkglyphs);
	memset(flags, 0, sizeof flags);
}

@end
