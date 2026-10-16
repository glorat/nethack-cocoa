//
//  ExtCommandWindowController.m
//  NetHackCocoa
//
//  Created by Bryce on 2/19/10.
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

#import "ExtCommandWindowController.h"
#import "ExtCommandInput.h"

static const CGFloat kMinWidth = 440;
static const CGFloat kMaxWidth = 760;
static const CGFloat kMargin = 20;
static const CGFloat kCellPadding = 8;

@interface ExtCommandWindowController () <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@end

// the field keeps the focus, so the table would draw its highlight as inactive
@interface ExtCommandRowView : NSTableRowView
@end

@implementation ExtCommandRowView

-(BOOL)isEmphasized
{
	return YES;
}

@end

@implementation ExtCommandWindowController {
	ExtCommandInput *			input;
	NSArray<NhExtCommand *> *	rows;
	NSString *					typed;
	NSTextField *				field;
	NSTableView *				table;
	void (^answer)(NSString *);
	BOOL						finished;
	NSDictionary *				nameAttributes;
	NSDictionary *				helpAttributes;
	CGFloat						helpStart;
	CGFloat						width;
}

+(void)askWithCommands:(NSArray<NhExtCommand *> *)commands answer:(void (^)(NSString * command))answer
{
	ExtCommandWindowController * win = [[ExtCommandWindowController alloc] initWithCommands:commands answer:answer];
	[win showWindow:win];
	[win.window makeFirstResponder:win->field];
	[NSApp runModalForWindow:win.window];
}

-(id)initWithCommands:(NSArray<NhExtCommand *> *)commands answer:(void (^)(NSString *))theAnswer
{
	NSPanel * panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, kMinWidth, 400)
												 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
												   backing:NSBackingStoreBuffered
													 defer:YES];
	if ( self = [super initWithWindow:panel] ) {
		input = [[ExtCommandInput alloc] initWithCommands:commands];
		answer = [theAnswer copy];
		typed = @"";
		rows = [input listForPrefix:typed];
		[self measureRows];
		panel.delegate = self;
		panel.title = @"";
		[self buildContents];
		[self placeWindow];
	}
	return self;
}

-(void)measureRows
{
	nameAttributes = @{ NSFontAttributeName : [NSFont systemFontOfSize:14 weight:NSFontWeightMedium],
						NSForegroundColorAttributeName : [NSColor labelColor] };
	helpAttributes = @{ NSFontAttributeName : [NSFont systemFontOfSize:13],
						NSForegroundColorAttributeName : [NSColor secondaryLabelColor] };
	CGFloat names = 0, helps = 0;
	for ( NhExtCommand * command in rows ) {
		names = MAX(names, [command.name sizeWithAttributes:nameAttributes].width);
		helps = MAX(helps, [command.help sizeWithAttributes:helpAttributes].width);
	}
	helpStart = ceil(names) + 24;
	CGFloat scroller = [NSScroller scrollerWidthForControlSize:NSControlSizeRegular scrollerStyle:NSScrollerStyleLegacy];
	CGFloat content = 2 * kCellPadding + helpStart + ceil(helps) + scroller + 4;
	width = MIN(kMaxWidth, MAX(kMinWidth, content + 2 * kMargin));
}

-(void)buildContents
{
	const CGFloat inner = width - 2 * kMargin;
	NSFont * font = [NSFont systemFontOfSize:14];

	NSTextField * hash = [NSTextField labelWithString:@"#"];
	hash.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightMedium];
	hash.textColor = [NSColor secondaryLabelColor];
	field = [NSTextField textFieldWithString:@""];
	field.font = font;
	field.placeholderString = @"Type a command";
	field.delegate = self;
	NSStackView * line = [NSStackView stackViewWithViews:@[ hash, field ]];
	line.spacing = 6;
	[line.widthAnchor constraintEqualToConstant:inner].active = YES;

	table = [[NSTableView alloc] init];
	NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"command"];
	column.resizingMask = NSTableColumnAutoresizingMask;
	[table addTableColumn:column];
	table.headerView = nil;
	table.style = NSTableViewStylePlain;
	table.rowHeight = 22;
	table.intercellSpacing = NSMakeSize(0, 2);
	table.allowsEmptySelection = YES;
	table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
	table.dataSource = self;
	table.delegate = self;
	table.target = self;
	table.action = @selector(rowClicked:);
	table.refusesFirstResponder = YES;
	NSScrollView * scroll = [[NSScrollView alloc] init];
	scroll.documentView = table;
	scroll.hasVerticalScroller = YES;
	scroll.autohidesScrollers = YES;
	scroll.borderType = NSBezelBorder;
	[scroll.widthAnchor constraintEqualToConstant:inner].active = YES;
	[scroll.heightAnchor constraintEqualToConstant:14 * 24].active = YES;

	NSTextField * hint = [NSTextField wrappingLabelWithString:@"Return runs the highlighted command, Esc cancels."];
	hint.font = [NSFont systemFontOfSize:12];
	hint.textColor = [NSColor secondaryLabelColor];

	NSStackView * stack = [NSStackView stackViewWithViews:@[ line, scroll, hint ]];
	stack.orientation = NSUserInterfaceLayoutOrientationVertical;
	stack.alignment = NSLayoutAttributeLeading;
	stack.spacing = 10;
	stack.edgeInsets = NSEdgeInsetsMake(20, kMargin, 16, kMargin);
	stack.translatesAutoresizingMaskIntoConstraints = NO;

	NSView * content = self.window.contentView;
	[content addSubview:stack];
	[NSLayoutConstraint activateConstraints:@[
		[stack.topAnchor constraintEqualToAnchor:content.topAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
		[stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
		[stack.widthAnchor constraintEqualToConstant:width],
	]];
	[self.window setContentSize:stack.fittingSize];
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

#pragma mark List

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return rows.count;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView * cell = [tableView makeViewWithIdentifier:@"command" owner:self];
	if ( cell == nil ) {
		cell = [[NSTableCellView alloc] init];
		cell.identifier = @"command";
		NSTextField * text = [NSTextField labelWithString:@""];
		text.translatesAutoresizingMaskIntoConstraints = NO;
		text.lineBreakMode = NSLineBreakByTruncatingTail;
		[cell addSubview:text];
		cell.textField = text;
		[NSLayoutConstraint activateConstraints:@[
			[text.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:kCellPadding],
			[text.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-kCellPadding],
			[text.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		]];
	}
	NhExtCommand * command = rows[row];
	// the paragraph style overrides the label's own line breaking
	NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
	style.tabStops = @[ [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:helpStart options:@{}] ];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	NSMutableAttributedString * title = [[NSMutableAttributedString alloc] initWithString:command.name attributes:nameAttributes];
	[title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"\t" stringByAppendingString:command.help] attributes:helpAttributes]];
	[title addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, title.length)];
	cell.textField.attributedStringValue = title;
	return cell;
}

-(NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	return [[ExtCommandRowView alloc] init];
}

-(void)highlightRow:(NSInteger)row
{
	if ( row < 0 || row >= (NSInteger)rows.count ) {
		[table deselectAll:nil];
		return;
	}
	[table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[table scrollRowToVisible:row];
}

-(void)rowClicked:(id)sender
{
	if ( table.clickedRow >= 0 )
		[self finishWith:rows[table.clickedRow].name];
}

#pragma mark Typing

-(void)controlTextDidChange:(NSNotification *)notification
{
	[self textChangedIn:notification.userInfo[@"NSFieldEditor"]];
}

-(void)textChangedIn:(NSText *)editor
{
	NSString * text = [editor.string copy];
	if ( finished || [text isEqualToString:typed] )
		return;
	NSString * completion = [input completionOf:text after:typed];
	typed = text;
	if ( completion.length > text.length ) {
		editor.string = completion;
		editor.selectedRange = NSMakeRange(text.length, completion.length - text.length);
	}
	rows = [input listForPrefix:typed];
	[table reloadData];
	[self highlightRow:typed.length ? 0 : -1];
}

-(BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if ( command == @selector(insertNewline:) ) {
		NhExtCommand * row = table.selectedRow >= 0 ? rows[table.selectedRow] : nil;
		[self finishWith:[input commandToRunFor:textView.string highlighted:row]];
	} else if ( command == @selector(cancelOperation:) ) {
		// as tty, Esc clears what's typed before it cancels
		if ( textView.string.length ) {
			textView.string = @"";
			[self textChangedIn:textView];
		} else {
			[self finishWith:@""];
		}
	} else if ( command == @selector(moveDown:) ) {
		[self highlightRow:MIN(table.selectedRow + 1, (NSInteger)rows.count - 1)];
	} else if ( command == @selector(moveUp:) ) {
		[self highlightRow:MAX(table.selectedRow - 1, 0)];
	} else {
		return NO;
	}
	return YES;
}

#pragma mark Finishing

-(void)finishWith:(NSString *)command
{
	if ( finished )
		return;
	finished = YES;
	answer(command);
	[self.window close];
}

-(BOOL)windowShouldClose:(id)sender
{
	[self finishWith:@""];
	return NO;
}

-(void)windowWillClose:(NSNotification *)notification
{
	[NSApp stopModal];
}

@end
