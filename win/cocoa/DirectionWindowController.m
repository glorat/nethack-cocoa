//
//  DirectionWindowController.m
//  NetHackCocoa
//
//  Created by Bryce on 2/18/10.
//  Copyright 2010 Bryce Cogswell. All rights reserved.
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

#import "DirectionWindowController.h"
#import "NhEventQueue.h"
#import "KeyEvent.h"

static const CGFloat kMargin = 20;
static const CGFloat kCell = 64;
static const CGFloat kGap = 6;

@implementation DirectionWindowController {
	NSString *	prompt;
	NSString *	directions;
	id			keyMonitor;
	BOOL		finished;
}

+(void)askWithPrompt:(NSString *)prompt directions:(NSString *)directions near:(NSRect)heroOnScreen
{
	DirectionWindowController * win = [[DirectionWindowController alloc] initWithPrompt:prompt directions:directions];
	NSRect visible = (NSApp.mainWindow.screen ?: NSScreen.mainScreen).visibleFrame;
	[win.window setFrame:[self frameForSize:win.window.frame.size near:heroOnScreen within:visible] display:NO];
	[win showWindow:win];
	[NSApp runModalForWindow:win.window];
}

// beside the hero rather than over it, so the map around them stays visible
+(NSRect)frameForSize:(NSSize)size near:(NSRect)hero within:(NSRect)visible
{
	const CGFloat gap = 24;
	NSRect frame = { NSZeroPoint, size };
	if ( NSIsEmptyRect(hero) ) {
		frame.origin.x = NSMidX(visible) - size.width / 2;
		frame.origin.y = NSMaxY(visible) - 60 - size.height;
	} else {
		frame.origin.x = NSMaxX(hero) + gap;
		if ( NSMaxX(frame) > NSMaxX(visible) )
			frame.origin.x = NSMinX(hero) - gap - size.width;
		frame.origin.y = NSMidY(hero) - size.height / 2;
	}
	frame.origin.x = round(MAX(NSMinX(visible), MIN(frame.origin.x, NSMaxX(visible) - size.width)));
	frame.origin.y = round(MAX(NSMinY(visible), MIN(frame.origin.y, NSMaxY(visible) - size.height)));
	return frame;
}

-(id)initWithPrompt:(NSString *)thePrompt directions:(NSString *)theDirections
{
	NSPanel * panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 300, 300)
												 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
												   backing:NSBackingStoreBuffered
													 defer:YES];
	if ( self = [super initWithWindow:panel] ) {
		prompt = [thePrompt copy];
		directions = [theDirections copy];
		panel.delegate = self;
		panel.title = @"";
		[self buildContents];
		[self installKeyMonitor];
	}
	return self;
}

-(NSButton *)buttonForKey:(char)key label:(NSString *)label image:(NSString *)imageName
{
	NSButton * button = [NSButton buttonWithTitle:@"" target:self action:@selector(directionClicked:)];
	button.translatesAutoresizingMaskIntoConstraints = NO;
	button.tag = key;
	button.bezelStyle = NSBezelStyleRegularSquare;
	NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%c", key] attributes:@{
		NSFontAttributeName : [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightMedium],
		NSForegroundColorAttributeName : [NSColor secondaryLabelColor] }];
	if ( label )
		[title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:label] attributes:@{
			NSFontAttributeName : [NSFont systemFontOfSize:13],
			NSForegroundColorAttributeName : [NSColor labelColor] }]];
	button.attributedTitle = title;
	if ( imageName ) {
		NSImage * image = [[NSImage imageNamed:imageName] copy];
		image.size = NSMakeSize(18, 18);
		button.image = image;
		button.imagePosition = NSImageLeading;
	}
	[button.heightAnchor constraintEqualToConstant:44].active = YES;
	return button;
}

-(void)buildContents
{
	const CGFloat gridWidth = 3 * kCell + 2 * kGap;
	NSStackView * stack = [[NSStackView alloc] init];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeCenterX;
	stack.spacing = kGap;
	stack.edgeInsets = NSEdgeInsetsMake(20, kMargin, 16, kMargin);
	stack.translatesAutoresizingMaskIntoConstraints = NO;

	NSTextField * label = [NSTextField wrappingLabelWithString:prompt];
	label.font = [NSFont boldSystemFontOfSize:15];
	label.preferredMaxLayoutWidth = gridWidth;
	[label.widthAnchor constraintEqualToConstant:gridWidth].active = YES;
	[stack addArrangedSubview:label];
	[stack setCustomSpacing:14 afterView:label];

	// indices into the core's direction order W NW N NE E SE S SW down up; -1 is self
	const int order[] = { 1, 2, 3, 0, -1, 4, 7, 6, 5 };
	NSString * images[] = { @"Arrow-NW", @"Arrow-N", @"Arrow-NE", @"Arrow-W", nil, @"Arrow-E", @"Arrow-SW", @"Arrow-S", @"Arrow-SE" };
	NSMutableArray * rows = [NSMutableArray array];
	for ( int r = 0; r < 3; ++r ) {
		NSMutableArray * row = [NSMutableArray array];
		for ( int c = 0; c < 3; ++c ) {
			int i = 3 * r + c;
			char key = order[i] < 0 ? '.' : [directions characterAtIndex:order[i]];
			NSButton * button = [self buttonForKey:key label:(order[i] < 0 ? @"Self" : nil) image:images[i]];
			[button.widthAnchor constraintEqualToConstant:kCell].active = YES;
			[row addObject:button];
		}
		[rows addObject:row];
	}
	NSGridView * grid = [NSGridView gridViewWithViews:rows];
	grid.rowSpacing = kGap;
	grid.columnSpacing = kGap;
	[stack addArrangedSubview:grid];

	NSButton * up = [self buttonForKey:[directions characterAtIndex:9] label:@"Up" image:nil];
	NSButton * down = [self buttonForKey:[directions characterAtIndex:8] label:@"Down" image:nil];
	NSStackView * vertical = [NSStackView stackViewWithViews:@[ up, down ]];
	vertical.spacing = kGap;
	vertical.distribution = NSStackViewDistributionFillEqually;
	[vertical.widthAnchor constraintEqualToConstant:gridWidth].active = YES;
	[stack addArrangedSubview:vertical];
	[stack setCustomSpacing:12 afterView:vertical];

	NSTextField * hint = [NSTextField wrappingLabelWithString:@"s also means self, ? lists the directions, Esc cancels."];
	hint.font = [NSFont systemFontOfSize:12];
	hint.textColor = [NSColor secondaryLabelColor];
	hint.preferredMaxLayoutWidth = gridWidth;
	[hint.widthAnchor constraintEqualToConstant:gridWidth].active = YES;
	[stack addArrangedSubview:hint];

	NSView * content = self.window.contentView;
	[content addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
	]];
	[self.window setContentSize:stack.fittingSize];
}

-(void)installKeyMonitor
{
	__weak DirectionWindowController * weakSelf = self;
	keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
		DirectionWindowController * strongSelf = weakSelf;
		if ( strongSelf == nil || event.window != strongSelf.window )
			return event;
		return [strongSelf handleKey:event] ? nil : event;
	}];
}

-(BOOL)handleKey:(NSEvent *)event
{
	if ( event.modifierFlags & NSEventModifierFlagCommand )
		return NO;
	// the core answers anything that isn't a direction as tty does: help for
	// '?', a map cursor for '_', cancel for Esc, a complaint for the rest
	int key = NhKeyFromEvent(event, directions.UTF8String);
	if ( key > 0 && key < 256 )
		[self answer:key];
	return YES;
}

-(void)directionClicked:(NSButton *)sender
{
	[self answer:(int)sender.tag];
}

-(void)answer:(int)key
{
	if ( finished )
		return;
	finished = YES;
	[[NhEventQueue instance] addKey:key];
	[self.window close];
}

-(BOOL)windowShouldClose:(id)sender
{
	[self answer:'\033'];
	return NO;
}

-(void)windowWillClose:(NSNotification *)notification
{
	if ( keyMonitor ) {
		[NSEvent removeMonitor:keyMonitor];
		keyMonitor = nil;
	}
	[NSApp stopModal];
}

@end
