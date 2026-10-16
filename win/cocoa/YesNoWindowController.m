//
//  YesNoWindowController.m
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

#import "YesNoWindowController.h"
#import "YesNoInput.h"
#import "NhYnQuestion.h"
#import "NhEventQueue.h"

static const CGFloat kWidth = 380;
static const CGFloat kMargin = 20;

@implementation YesNoWindowController {
	NhYnQuestion *	question;
	YesNoInput *	input;
	NSTextField *	countLabel;
	id				keyMonitor;
	BOOL			finished;
}

+(BOOL)canAskWithChoices:(const char *)choices
{
	return [YesNoInput canAskWithChoices:choices];
}

+(void)askQuestion:(NhYnQuestion *)q
{
	YesNoWindowController * win = [[YesNoWindowController alloc] initWithQuestion:q];
	[win showWindow:win];
	[NSApp runModalForWindow:[win window]];
}

-(id)initWithQuestion:(NhYnQuestion *)q
{
	NSPanel * panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, kWidth, 100)
												 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
												   backing:NSBackingStoreBuffered
													 defer:YES];
	if ( self = [super initWithWindow:panel] ) {
		question = q;
		input = [[YesNoInput alloc] initWithChoices:q.choices default:q.def];
		panel.delegate = self;
		panel.title = @"";
		[self buildContents];
		[self installKeyMonitor];
	}
	return self;
}

-(BOOL)isHorizontal
{
	if ( input.answers.length > 3 )
		return NO;
	for ( NSUInteger i = 0; i < input.answers.length; ++i ) {
		if ( [input labelForAnswer:[input.answers characterAtIndex:i]].length > 12 )
			return NO;
	}
	return YES;
}

// every button shows its key, so players learn to answer from the keyboard
-(NSButton *)buttonForAnswer:(unichar)c inRow:(BOOL)inRow
{
	NSString * label = [input labelForAnswer:c];
	NSButton * button = [NSButton buttonWithTitle:label target:self action:@selector(answerClicked:)];
	button.translatesAutoresizingMaskIntoConstraints = NO;
	button.tag = c;
	NSFont * font = [NSFont systemFontOfSize:inRow ? NSFont.systemFontSize : 14];
	NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
	if ( !inRow ) {
		button.controlSize = NSControlSizeLarge;
		button.alignment = NSTextAlignmentLeft;
		style.alignment = NSTextAlignmentLeft;
	} else {
		style.alignment = NSTextAlignmentCenter;
	}
	BOOL isDefault = c == question.def;
	NSColor * labelColor = isDefault ? [NSColor alternateSelectedControlTextColor] : [NSColor labelColor];
	NSColor * keyColor = isDefault ? [labelColor colorWithAlphaComponent:0.7] : [NSColor secondaryLabelColor];
	BOOL named = label.length > 1 || [label characterAtIndex:0] != c;
	NSString * key = [NSString stringWithFormat:named ? (inRow ? @"%C  " : @"%C   ") : @"%C", c];
	NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:key attributes:@{
		NSFontAttributeName : [NSFont monospacedSystemFontOfSize:font.pointSize weight:NSFontWeightMedium],
		NSForegroundColorAttributeName : keyColor }];
	if ( named )
		[title appendAttributedString:[[NSAttributedString alloc] initWithString:label attributes:@{
			NSFontAttributeName : font,
			NSForegroundColorAttributeName : labelColor }]];
	[title addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, title.length)];
	button.attributedTitle = title;
	if ( isDefault )
		button.keyEquivalent = @"\r";
	return button;
}

-(void)buildContents
{
	const CGFloat inner = kWidth - 2 * kMargin;
	NSStackView * stack = [[NSStackView alloc] init];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 8;
	stack.edgeInsets = NSEdgeInsetsMake(20, kMargin, 16, kMargin);
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	NSMutableArray * constraints = [NSMutableArray array];

	NSTextField * prompt = [NSTextField wrappingLabelWithString:question.question];
	prompt.font = [NSFont boldSystemFontOfSize:15];
	prompt.preferredMaxLayoutWidth = inner;
	[stack addArrangedSubview:prompt];
	[stack setCustomSpacing:14 afterView:prompt];

	if ( input.allowsCount ) {
		countLabel = [NSTextField wrappingLabelWithString:@""];
		countLabel.font = [NSFont systemFontOfSize:12];
		countLabel.textColor = [NSColor secondaryLabelColor];
		countLabel.preferredMaxLayoutWidth = inner;
		[self updateCountLabel];
		[stack addArrangedSubview:countLabel];
		[stack setCustomSpacing:14 afterView:countLabel];
	}

	NSString * answers = input.answers;
	if ( [self isHorizontal] ) {
		NSStackView * bar = [NSStackView stackViewWithViews:@[]];
		for ( NSUInteger i = 0; i < answers.length; ++i )
			[bar insertView:[self buttonForAnswer:[answers characterAtIndex:i] inRow:YES] atIndex:0 inGravity:NSStackViewGravityTrailing];
		[stack addArrangedSubview:bar];
		[constraints addObject:[bar.widthAnchor constraintEqualToConstant:inner]];
	} else {
		for ( NSUInteger i = 0; i < answers.length; ++i ) {
			NSButton * button = [self buttonForAnswer:[answers characterAtIndex:i] inRow:NO];
			[stack addArrangedSubview:button];
			[constraints addObject:[button.widthAnchor constraintEqualToConstant:inner]];
		}
	}

	NSView * content = self.window.contentView;
	[content addSubview:stack];
	[constraints addObjectsFromArray:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
		[stack.widthAnchor constraintEqualToConstant:kWidth],
	]];
	[NSLayoutConstraint activateConstraints:constraints];
	[self.window setContentSize:stack.fittingSize];
	[self placeWindow];
}

-(void)placeWindow
{
	NSRect visible = (NSApp.mainWindow.screen ?: NSScreen.mainScreen).visibleFrame;
	NSRect main = NSApp.mainWindow ? NSApp.mainWindow.frame : visible;
	NSRect frame = self.window.frame;
	frame.origin.x = round(NSMidX(main) - frame.size.width / 2);
	frame.origin.y = round(MIN(NSMaxY(main) - 60, NSMaxY(visible)) - frame.size.height);
	frame.origin.x = MAX(NSMinX(visible), MIN(frame.origin.x, NSMaxX(visible) - frame.size.width));
	frame.origin.y = MAX(NSMinY(visible), frame.origin.y);
	[self.window setFrame:frame display:NO];
}

-(void)updateCountLabel
{
	countLabel.stringValue = input.counting
		? [NSString stringWithFormat:@"Count: %ld. Press Return to take that many.", input.count]
		: @"Type a number first to take only that many.";
}

-(void)installKeyMonitor
{
	__weak YesNoWindowController * weakSelf = self;
	keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
		YesNoWindowController * strongSelf = weakSelf;
		if ( strongSelf == nil || event.window != strongSelf.window )
			return event;
		return [strongSelf handleKey:event] ? nil : event;
	}];
}

-(void)apply:(YesNoResult)result
{
	switch ( result ) {
		case YesNoAnswered:
			[self finish];
			break;
		case YesNoCountChanged:
			[self updateCountLabel];
			break;
		case YesNoBeep:
			NSBeep();
			break;
		case YesNoIgnored:
			break;
	}
}

-(BOOL)handleKey:(NSEvent *)event
{
	NSString * chars = event.characters;
	if ( chars.length == 0 || (event.modifierFlags & NSEventModifierFlagCommand) )
		return NO;
	unichar c = [chars characterAtIndex:0];
	if ( (event.modifierFlags & NSEventModifierFlagControl) && c != 3 )
		return NO;
	[self apply:[input typeKey:c]];
	return YES;
}

-(void)answerClicked:(NSButton *)sender
{
	[self apply:[input pressAnswer:(unichar)sender.tag]];
}

-(void)finish
{
	if ( finished )
		return;
	finished = YES;
	if ( input.answer == '#' )
		question.count = input.count;
	[[NhEventQueue instance] addKey:input.answer];
	[self.window close];
}

-(BOOL)windowShouldClose:(id)sender
{
	[self apply:[input cancel]];
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
