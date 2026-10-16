//
//  EquipmentView.m
//  NetHackCocoa
//
//  Created by Bryce on 3/14/10.
//  Copyright 2010 Bryce Cogswell All rights reserved.
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

#import <Cocoa/Cocoa.h>

#import "hack.h"
#undef yn	// avoid conflict with math.h

#import "EquipmentView.h"
#import "TileSet.h"

#define CELL	32.0
#define COLS	3
#define ROWS	4
#define GRID_TOP	21.0

static NSString * const s_slotNames[COLS*ROWS] = {
	@"amulet",		@"helmet",	@"blindfold/lenses",
	@"weapon",		@"armor",	@"shield",
	@"gloves",		@"shirt",	@"cloak",
	@"left ring",	@"boots",	@"right ring",
};

@implementation EquipmentView

- (id)initWithCoder:(NSCoder *)coder
{
	if ( self = [super initWithCoder:coder] ) {
		for ( int slot = 0; slot < COLS*ROWS; ++slot )
			glyphs[slot] = NO_GLYPH;
	}
	return self;
}

- (BOOL)isFlipped
{
	return YES;
}

- (NSRect)gridRect
{
	CGFloat width = COLS * (CELL + 1) + 1;
	CGFloat height = ROWS * (CELL + 1) + 1;
	return NSMakeRect(floor((self.bounds.size.width - width) / 2), GRID_TOP, width, height);
}

- (NSRect)rectForSlot:(int)slot
{
	NSRect grid = [self gridRect];
	return NSMakeRect(grid.origin.x + 1 + (slot % COLS) * (CELL + 1), grid.origin.y + 1 + (slot / COLS) * (CELL + 1), CELL, CELL);
}

- (void)drawRect:(NSRect)dirtyRect
{
	[[NSColor colorWithWhite:0.56 alpha:1.0] set];
	NSRectFill([self gridRect]);

	TileSet * tileSet = [TileSet instance];
	NSSize tileSize = tileSet.tileSize;
	for ( int slot = 0; slot < COLS*ROWS; ++slot ) {
		NSRect cell = [self rectForSlot:slot];
		[[NSColor colorWithWhite:0.72 alpha:1.0] set];
		NSRectFill(cell);
		if ( glyphs[slot] == NO_GLYPH || tileSet == nil )
			continue;

		CGFloat scale = MIN(CELL / tileSize.width, CELL / tileSize.height);
		if ( scale > 1.0 )
			scale = floor(scale);
		NSSize size = NSMakeSize(round(tileSize.width * scale), round(tileSize.height * scale));
		NSRect r = NSMakeRect(cell.origin.x + floor((CELL - size.width) / 2), cell.origin.y + floor((CELL - size.height) / 2), size.width, size.height);
		[[NSGraphicsContext currentContext] setImageInterpolation:scale < 1.0 ? NSImageInterpolationMedium : NSImageInterpolationNone];
		[tileSet.image drawInRect:r fromRect:[tileSet sourceRectForGlyph:glyphs[slot]] operation:NSCompositingOperationSourceOver fraction:1.0f respectFlipped:YES hints:nil];
	}
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data
{
	return tips[(NSInteger)data];
}

- (void)updateInventory
{
	if ( program_state.gameover ) {
		// A end of game these objects may become deallocated causing a crash
		return;
	}

	struct obj * items[COLS*ROWS] = {
		uamul,	uarmh,	ublindf,
		uwep,	uarm,	u.twoweap ? uswapwep : uarms,
		uarmg,	uarmu,	uarmc,
		uleft,	uarmf,	uright,
	};
	NSMutableArray * newTips = [NSMutableArray array];
	[self removeAllToolTips];
	for ( int slot = 0; slot < COLS*ROWS; ++slot ) {
		struct obj * item = items[slot];
		NSString * text = s_slotNames[slot];
		glyphs[slot] = item ? obj_to_glyph(item, rn2_on_display_rng) : NO_GLYPH;
		if ( glyphs[slot] != NO_GLYPH ) {
			text = [NSString stringWithFormat:@"(%c) %s", item->invlet, doname(item)];
			if ( [text hasSuffix:@" (being worn)"] )
				text = [text substringToIndex:[text length] - 13];
		}
		[newTips addObject:text];
		[self addToolTipRect:[self rectForSlot:slot] owner:self userData:(void *)(NSInteger)slot];
	}
	tips = newTips;
	[self setNeedsDisplay:YES];
}

@end
