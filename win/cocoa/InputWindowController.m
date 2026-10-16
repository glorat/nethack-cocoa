//
//  InputWindowController.m
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

#import "InputWindowController.h"

static const CGFloat kWidth = 480;
static const CGFloat kMargin = 20;

@interface InputWindowController () <NSTextFieldDelegate>
@end

@implementation InputWindowController {
	NSTextField *			field;
	void (^answer)(NSString *);
	BOOL					finished;
}

+(void)askWithPrompt:(NSString *)prompt parent:(NSWindow *)parent answer:(void (^)(NSString * text))answer
{
	InputWindowController * win = [[InputWindowController alloc] initWithPrompt:prompt answer:answer];
	if ( parent.isVisible ) {
		[parent beginSheet:win.window completionHandler:nil];
	} else {
		[win.window center];
		[win showWindow:win];
	}
	[win.window makeFirstResponder:win->field];
	[NSApp runModalForWindow:win.window];
}

-(id)initWithPrompt:(NSString *)prompt answer:(void (^)(NSString *))theAnswer
{
	NSPanel * panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, kWidth, 100)
												 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
												   backing:NSBackingStoreBuffered
													 defer:YES];
	if ( self = [super initWithWindow:panel] ) {
		answer = [theAnswer copy];
		panel.delegate = self;
		panel.title = @"";
		[self buildContentsWithPrompt:prompt];
	}
	return self;
}

-(void)buildContentsWithPrompt:(NSString *)prompt
{
	const CGFloat inner = kWidth - 2 * kMargin;

	NSTextField * label = [NSTextField wrappingLabelWithString:prompt];
	label.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
	label.preferredMaxLayoutWidth = inner;
	[label.widthAnchor constraintEqualToConstant:inner].active = YES;

	field = [NSTextField textFieldWithString:@""];
	field.font = [NSFont systemFontOfSize:14];
	field.delegate = self;
	[field.widthAnchor constraintEqualToConstant:inner].active = YES;

	NSButton * cancel = [NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancel:)];
	NSButton * ok = [NSButton buttonWithTitle:@"OK" target:self action:@selector(accept:)];
	ok.keyEquivalent = @"\r";
	NSStackView * buttons = [[NSStackView alloc] init];
	[buttons setViews:@[ cancel, ok ] inGravity:NSStackViewGravityTrailing];
	buttons.spacing = 8;
	[buttons.widthAnchor constraintEqualToConstant:inner].active = YES;

	NSStackView * stack = [NSStackView stackViewWithViews:@[ label, field, buttons ]];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 12;
	stack.edgeInsets = NSEdgeInsetsMake(20, kMargin, 16, kMargin);
	stack.translatesAutoresizingMaskIntoConstraints = NO;

	NSView * content = self.window.contentView;
	[content addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
		[stack.widthAnchor constraintEqualToConstant:kWidth],
	]];
	[self.window setContentSize:stack.fittingSize];
}

-(BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if ( command == @selector(insertNewline:) ) {
		[self finishWith:[textView.string copy]];
	} else if ( command == @selector(cancelOperation:) ) {
		// as tty, Esc clears what's typed before it cancels
		if ( textView.string.length )
			textView.string = @"";
		else
			[self finishWith:@"\033"];
	} else {
		return NO;
	}
	return YES;
}

-(void)accept:(id)sender
{
	[self finishWith:[field.stringValue copy]];
}

-(void)cancel:(id)sender
{
	[self finishWith:@"\033"];
}

-(void)finishWith:(NSString *)text
{
	if ( finished )
		return;
	finished = YES;
	answer(text);
	NSWindow * parent = self.window.sheetParent;
	if ( parent )
		[parent endSheet:self.window];
	[self.window close];
}

-(BOOL)windowShouldClose:(id)sender
{
	[self cancel:sender];
	return NO;
}

-(void)windowWillClose:(NSNotification *)notification
{
	[NSApp stopModal];
}

@end
