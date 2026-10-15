//
//  MenuWindowController.m
//  NetHackCocoa
//
//  Created by Bryce on 2/16/10.
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



#import "MenuWindowController.h"
#import "NhMenuWindow.h"
#import "NhItem.h"
#import "NhItemGroup.h"
#import "TileSet.h"
#import "NhEventQueue.h"

static const CGFloat kTileSize		= 24.0;
static const CGFloat kTileGap		= 6.0;
static const CGFloat kLetterWidth	= 24.0;
static const CGFloat kColumnGap		= 16.0;
static const CGFloat kCheckboxWidth	= 24.0;
static const CGFloat kMargin		= 16.0;
static const CGFloat kButtonBar		= 52.0;


@interface MenuRow : NSObject
@property (nonatomic, strong) NhItem * item;	// nil for a line of text
@property (nonatomic, strong) NSArray<NSString *> * fields;
@property (nonatomic, assign) BOOL heading;
@property (nonatomic, assign) CGFloat start;	// where the first field begins
@end

@implementation MenuRow
@end


// tty lays out columns with runs of spaces; a run after a full stop is just the end of a sentence
static NSArray<NSString *> * SplitFields( NSString * text )
{
	text = [text stringByReplacingOccurrencesOfString:@"\t" withString:@"  "];
	NSMutableArray * fields = [NSMutableArray array];
	NSUInteger len = text.length, start = 0, i = 0;
	while ( i < len ) {
		if ( [text characterAtIndex:i] == ' ' && i+1 < len && [text characterAtIndex:i+1] == ' ' && i > start ) {
			NSUInteger end = i;
			while ( end < len && [text characterAtIndex:end] == ' ' )
				++end;
			unichar prev = [text characterAtIndex:i-1];
			if ( end < len && prev != '.' && prev != '!' && prev != '?' && prev != ',' ) {
				[fields addObject:[text substringWithRange:NSMakeRange(start, i-start)]];
				start = end;
			}
			i = end;
		} else {
			++i;
		}
	}
	[fields addObject:[text substringFromIndex:start]];
	return fields;
}

static NSUInteger LeadingSpaces( NSString * text )
{
	NSUInteger i = 0;
	while ( i < text.length && [text characterAtIndex:i] == ' ' )
		++i;
	return i;
}

static NSString * SortKey( NSString * title )
{
	static NSArray * prefixes = nil;
	if ( prefixes == nil ) {
		prefixes = @[ @"a ", @"an ", @"the ", @"blessed ", @"cursed ", @"uncursed ",
					  @"very ", @"thoroughly ", @"rustproof ", @"fireproof ", @"corrodeproof ", @"fixed ",
					  @"rusty ", @"burnt ", @"corroded ", @"rotted ", @"partly eaten " ];
	}
	NSString * s = title;
	BOOL changed = YES;
	while ( changed ) {
		changed = NO;
		NSUInteger sign = s.length && ([s characterAtIndex:0] == '+' || [s characterAtIndex:0] == '-') ? 1 : 0;
		NSUInteger digits = sign;
		while ( digits < s.length && isdigit([s characterAtIndex:digits]) )
			++digits;
		if ( digits > sign && digits < s.length && [s characterAtIndex:digits] == ' ' ) {
			s = [s substringFromIndex:digits+1];
			changed = YES;
		}
		for ( NSString * prefix in prefixes ) {
			if ( [s hasPrefix:prefix] ) {
				s = [s substringFromIndex:prefix.length];
				changed = YES;
			}
		}
	}
	return s;
}


@interface MenuTableView : NSTableView
@end

@implementation MenuTableView
// let clicks on a row's checkbox reach it instead of starting a selection
- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event
{
	return YES;
}
@end


@implementation MenuWindowController
{
	NhMenuWindow		*	menuParams;
	int						how;
	NSMutableArray<MenuRow *> *	rows;
	NSMutableSet		*	checked;
	NSFont				*	bodyFont;
	NSFont				*	headingFont;
	NSParagraphStyle	*	paragraphStyle;
	BOOL					hasTiles;
	BOOL					hasLetters;
	CGFloat					itemStart;
	CGFloat					contentWidth;
	NSTableView			*	tableView;
	NSTextView			*	textView;
	NSButton			*	sortButton;
	int						count;
	id						keyMonitor;
	BOOL					finished;
}

#pragma mark Building rows

-(void)buildRows
{
	rows = [NSMutableArray array];
	checked = [NSMutableSet set];
	hasTiles = NO;
	hasLetters = NO;

	BOOL hasItems = NO;
	NSMutableSet * usedLetters = [NSMutableSet set];
	for ( NhItemGroup * group in menuParams.itemGroups ) {
		for ( NhItem * item in group.items ) {
			hasItems = YES;
			if ( item.glyph != NO_GLYPH )
				hasTiles = YES;
			if ( item.inventoryLetter )
				[usedLetters addObject:@(item.inventoryLetter)];
		}
	}

	// tty hands out letters to items that the core didn't give one
	const char * nextLetter = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
	if ( how != PICK_NONE ) {
		for ( NhItemGroup * group in menuParams.itemGroups ) {
			for ( NhItem * item in group.items ) {
				if ( item.inventoryLetter == 0 ) {
					while ( *nextLetter && [usedLetters containsObject:@(*nextLetter)] )
						++nextLetter;
					if ( *nextLetter )
						[item setInventoryLetter:*nextLetter++];
				}
			}
		}
	}
	for ( NhItemGroup * group in menuParams.itemGroups ) {
		for ( NhItem * item in group.items ) {
			if ( item.inventoryLetter )
				hasLetters = YES;
		}
	}

	itemStart = (hasTiles ? kTileSize + kTileGap : 0) + (hasLetters ? kLetterWidth : 0);
	CGFloat spaceWidth = [@" " sizeWithAttributes:@{ NSFontAttributeName : bodyFont }].width;

	for ( NhItemGroup * group in menuParams.itemGroups ) {
		if ( !group.dummy ) {
			NSString * title = group.title;
			NSUInteger spaces = LeadingSpaces(title);
			NSString * text = [[title substringFromIndex:spaces] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			MenuRow * row = [MenuRow new];
			row.fields = SplitFields(text);
			row.heading = group.items.count > 0
						|| (group.attr != ATR_NONE && text.length > 0)
						|| (spaces == 0 && [text hasSuffix:@":"]);
			// in tty, text indented by four spaces lines up with the items after "a - "
			if ( hasItems && spaces >= 4 && itemStart > 0 ) {
				row.start = itemStart + (spaces - 4) * spaceWidth;
			} else {
				row.start = spaces * spaceWidth * 2;
			}
			[rows addObject:row];
		}
		for ( NhItem * item in group.items ) {
			MenuRow * row = [MenuRow new];
			row.item = item;
			NSString * text = [item.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if ( item.detail )
				text = [text stringByAppendingFormat:@" (%@)", item.detail];
			row.fields = SplitFields(text);
			row.start = itemStart;
			[rows addObject:row];
			if ( item.selected )
				[checked addObject:item];
		}
	}
}

-(NSFont *)fontForRow:(MenuRow *)row
{
	return row.heading ? headingFont : bodyFont;
}

// column positions shared by every row, so items, headings and text line up
-(void)computeTabStops
{
	NSMutableArray<NSNumber *> * columns = [NSMutableArray array];
	NSUInteger maxFields = 0;
	for ( MenuRow * row in rows )
		maxFields = MAX(maxFields, row.fields.count);

	NSMutableArray<NSNumber *> * rowX = [NSMutableArray array];
	for ( MenuRow * row in rows )
		[rowX addObject:@(row.start)];

	for ( NSUInteger c = 0; c + 1 < maxFields; ++c ) {
		CGFloat next = 0;
		for ( NSUInteger r = 0; r < rows.count; ++r ) {
			MenuRow * row = rows[r];
			if ( row.fields.count > c + 1 ) {
				CGFloat x = c == 0 ? row.start : columns[c-1].doubleValue;
				CGFloat w = [row.fields[c] sizeWithAttributes:@{ NSFontAttributeName : [self fontForRow:row] }].width;
				next = MAX(next, ceil(x + w + kColumnGap));
			}
		}
		[columns addObject:@(next)];
	}

	NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
	NSMutableArray * tabs = [NSMutableArray array];
	if ( hasTiles )
		[tabs addObject:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:kTileSize + kTileGap options:@{}]];
	if ( hasLetters )
		[tabs addObject:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:itemStart options:@{}]];
	for ( NSNumber * x in columns )
		[tabs addObject:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:x.doubleValue options:@{}]];
	style.tabStops = tabs;
	style.lineBreakMode = NSLineBreakByClipping;
	paragraphStyle = style;

	contentWidth = 0;
	for ( MenuRow * row in rows ) {
		NSUInteger last = row.fields.count - 1;
		CGFloat x = last == 0 ? row.start : columns[last-1].doubleValue;
		CGFloat w = [row.fields[last] sizeWithAttributes:@{ NSFontAttributeName : [self fontForRow:row] }].width;
		contentWidth = MAX(contentWidth, ceil(x + w));
	}
}

-(NSAttributedString *)stringForRow:(MenuRow *)row
{
	NSMutableParagraphStyle * style = [paragraphStyle mutableCopy];
	NSDictionary * attributes = @{ NSFontAttributeName : [self fontForRow:row],
								   NSForegroundColorAttributeName : [NSColor labelColor],
								   NSParagraphStyleAttributeName : style };
	NSMutableAttributedString * s = [[NSMutableAttributedString alloc] init];

	if ( row.item ) {
		if ( hasTiles ) {
			if ( row.item.glyph != NO_GLYPH ) {
				NSTextAttachment * attachment = [[NSTextAttachment alloc] init];
				attachment.image = [[TileSet instance] imageForGlyph:row.item.glyph enabled:YES];
				CGFloat capHeight = bodyFont.capHeight;
				attachment.bounds = NSMakeRect(0, round((capHeight - kTileSize) / 2), kTileSize, kTileSize);
				[s appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
			}
			[s appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t" attributes:attributes]];
		}
		if ( hasLetters ) {
			NSString * letter = row.item.inventoryLetter ? [NSString stringWithFormat:@"%c", row.item.inventoryLetter] : @"";
			NSDictionary * letterAttributes = @{ NSFontAttributeName : [NSFont monospacedSystemFontOfSize:bodyFont.pointSize weight:NSFontWeightMedium],
												 NSForegroundColorAttributeName : [NSColor secondaryLabelColor],
												 NSParagraphStyleAttributeName : style };
			[s appendAttributedString:[[NSAttributedString alloc] initWithString:letter attributes:letterAttributes]];
			[s appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t" attributes:attributes]];
		}
	} else {
		style.firstLineHeadIndent = row.start;
		style.headIndent = row.start;
	}

	NSString * text = [row.fields componentsJoinedByString:@"\t"];
	[s appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
	[s addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, s.length)];
	return s;
}

#pragma mark Window

- (id)initWithMenu:(NhMenuWindow *)menu
{
	NSPanel * panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
												 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
												   backing:NSBackingStoreBuffered
													 defer:YES];
	if ( self = [super initWithWindow:panel] ) {
		menuParams = menu;
		how = menu.how;
		panel.delegate = self;
		panel.title = menu.prompt ?: @"";
		bodyFont = [NSFont systemFontOfSize:14];
		headingFont = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
		[self buildRows];
		[self computeTabStops];
		[self buildContents];
		[self installKeyMonitor];
	}
	return self;
}

-(NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action
{
	NSButton * button = [NSButton buttonWithTitle:title target:self action:action];
	button.translatesAutoresizingMaskIntoConstraints = NO;
	return button;
}

-(void)buildContents
{
	NSView * content = self.window.contentView;
	NSScrollView * scrollView = [[NSScrollView alloc] init];
	scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	scrollView.hasVerticalScroller = YES;
	scrollView.autohidesScrollers = YES;
	scrollView.borderType = NSNoBorder;
	[content addSubview:scrollView];

	CGFloat documentHeight;
	CGFloat documentWidth;
	if ( how == PICK_NONE ) {
		documentWidth = contentWidth + 2 * kMargin + 10;
		textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, documentWidth, 100)];
		textView.editable = NO;
		textView.selectable = YES;
		textView.textContainerInset = NSMakeSize(kMargin, 12);
		textView.autoresizingMask = NSViewWidthSizable;
		textView.textContainer.widthTracksTextView = YES;
		NSMutableAttributedString * all = [[NSMutableAttributedString alloc] init];
		for ( MenuRow * row in rows ) {
			if ( all.length )
				[all appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
			[all appendAttributedString:[self stringForRow:row]];
		}
		[textView.textStorage setAttributedString:all];
		[textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
		documentHeight = [textView.layoutManager usedRectForTextContainer:textView.textContainer].size.height + 24;
		scrollView.documentView = textView;
	} else {
		CGFloat rowHeight = hasTiles ? kTileSize + 6 : 22;
		tableView = [[MenuTableView alloc] init];
		NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"menu"];
		column.resizingMask = NSTableColumnAutoresizingMask;
		[tableView addTableColumn:column];
		tableView.headerView = nil;
		tableView.style = NSTableViewStylePlain;
		tableView.rowHeight = rowHeight;
		tableView.intercellSpacing = NSMakeSize(0, 2);
		tableView.allowsTypeSelect = NO;
		tableView.allowsEmptySelection = YES;
		tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
		tableView.dataSource = self;
		tableView.delegate = self;
		tableView.target = self;
		tableView.action = @selector(rowClicked:);
		scrollView.documentView = tableView;
		scrollView.automaticallyAdjustsContentInsets = NO;
		scrollView.contentInsets = NSEdgeInsetsMake(6, 0, 6, 0);
		documentWidth = contentWidth + 2 * kMargin + (how == PICK_ANY ? kCheckboxWidth : 0) + 20;
		documentHeight = rows.count * (rowHeight + 2) + 14;
	}

	// buttons
	NSButton * accept = [self buttonWithTitle:(how == PICK_NONE ? @"Close" : @"OK") action:@selector(doAccept:)];
	accept.keyEquivalent = @"\r";
	NSStackView * right = [NSStackView stackViewWithViews:@[ accept ]];
	if ( how != PICK_NONE ) {
		NSButton * cancel = [self buttonWithTitle:@"Cancel" action:@selector(doCancel:)];
		[right insertView:cancel atIndex:0 inGravity:NSStackViewGravityLeading];
	}
	right.translatesAutoresizingMaskIntoConstraints = NO;
	[content addSubview:right];

	NSStackView * left = [NSStackView stackViewWithViews:@[]];
	left.translatesAutoresizingMaskIntoConstraints = NO;
	if ( how == PICK_ANY ) {
		[left addView:[self buttonWithTitle:@"Select All" action:@selector(selectAll:)] inGravity:NSStackViewGravityLeading];
	}
	if ( how != PICK_NONE && hasTiles ) {
		sortButton = [NSButton checkboxWithTitle:@"Sort A–Z" target:self action:@selector(sortItems:)];
		[left addView:sortButton inGravity:NSStackViewGravityLeading];
	}
	[content addSubview:left];

	[NSLayoutConstraint activateConstraints:@[
		[scrollView.topAnchor constraintEqualToAnchor:content.topAnchor],
		[scrollView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
		[scrollView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kButtonBar],
		[right.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-kMargin],
		[right.centerYAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kButtonBar/2],
		[left.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:kMargin],
		[left.centerYAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kButtonBar/2],
		[left.trailingAnchor constraintLessThanOrEqualToAnchor:right.leadingAnchor constant:-kMargin],
	]];

	// size the window to the contents, within the screen
	NSRect visible = (NSApp.mainWindow.screen ?: NSScreen.mainScreen).visibleFrame;
	CGFloat width = MIN(MAX(documentWidth, 360), visible.size.width * 0.9);
	CGFloat height = MIN(MAX(documentHeight, 60) + kButtonBar, visible.size.height * 0.85);
	[self.window setContentSize:NSMakeSize(width, height)];
	self.window.contentMinSize = NSMakeSize(300, 160);
	NSRect main = NSApp.mainWindow ? NSApp.mainWindow.frame : visible;
	NSRect frame = self.window.frame;
	frame.origin.x = round(NSMidX(main) - frame.size.width / 2);
	frame.origin.y = round(MIN(NSMaxY(main) - 60, NSMaxY(visible)) - frame.size.height);
	frame.origin.x = MAX(NSMinX(visible), MIN(frame.origin.x, NSMaxX(visible) - frame.size.width));
	frame.origin.y = MAX(NSMinY(visible), frame.origin.y);
	[self.window setFrame:frame display:NO];

	if ( tableView ) {
		[tableView sizeLastColumnToFit];
		[self.window makeFirstResponder:tableView];
	} else {
		[self.window makeFirstResponder:textView];
	}
}

#pragma mark Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
	return rows.count;
}

- (BOOL)tableView:(NSTableView *)tv isGroupRow:(NSInteger)r
{
	return rows[r].heading && rows[r].item == nil;
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)r
{
	return rows[r].item != nil;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)column row:(NSInteger)r
{
	MenuRow * row = rows[r];
	NSTableCellView * cell = [[NSTableCellView alloc] init];
	if ( how == PICK_ANY && row.item ) {
		NSButton * box = [NSButton checkboxWithTitle:@"" target:self action:@selector(checkboxClicked:)];
		box.translatesAutoresizingMaskIntoConstraints = NO;
		box.state = [checked containsObject:row.item] ? NSControlStateValueOn : NSControlStateValueOff;
		box.tag = r;
		[cell addSubview:box];
		[NSLayoutConstraint activateConstraints:@[
			[box.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:kMargin],
			[box.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		]];
	}
	CGFloat leading = kMargin + (how == PICK_ANY ? kCheckboxWidth : 0);
	NSTextField * label = [NSTextField labelWithAttributedString:[self stringForRow:row]];
	label.translatesAutoresizingMaskIntoConstraints = NO;
	label.lineBreakMode = NSLineBreakByClipping;
	[label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
	[cell addSubview:label];
	cell.textField = label;
	// a text field's own width leaves out the paragraph indent
	NSLayoutConstraint * width = [label.widthAnchor constraintEqualToConstant:contentWidth + 4];
	width.priority = NSLayoutPriorityDefaultHigh;
	[NSLayoutConstraint activateConstraints:@[
		[label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:leading],
		[label.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-4],
		[label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		width,
	]];
	return cell;
}

-(void)reloadRowForItem:(NhItem *)item
{
	for ( NSUInteger r = 0; r < rows.count; ++r ) {
		if ( rows[r].item == item ) {
			[tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:r] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
			[tableView scrollRowToVisible:r];
			return;
		}
	}
}

-(void)toggleItem:(NhItem *)item
{
	if ( [checked containsObject:item] ) {
		[checked removeObject:item];
		item.amount = -1;
	} else {
		[checked addObject:item];
		item.amount = count > 0 ? count : -1;
	}
	count = 0;
	[self reloadRowForItem:item];
}

-(void)chooseItem:(NhItem *)item
{
	if ( how == PICK_ONE ) {
		[checked removeAllObjects];
		[checked addObject:item];
		item.amount = count > 0 ? count : -1;
		[self doAccept:nil];
	} else if ( how == PICK_ANY ) {
		[self toggleItem:item];
	}
}

-(void)rowClicked:(id)sender
{
	NSInteger r = tableView.clickedRow;
	if ( r >= 0 && rows[r].item )
		[self chooseItem:rows[r].item];
}

-(void)checkboxClicked:(NSButton *)sender
{
	NhItem * item = rows[sender.tag].item;
	if ( sender.state == NSControlStateValueOn )
		[checked addObject:item];
	else
		[checked removeObject:item];
}

-(void)setAllChecked:(BOOL)on
{
	for ( MenuRow * row in rows ) {
		if ( row.item ) {
			if ( on )
				[checked addObject:row.item];
			else
				[checked removeObject:row.item];
		}
	}
	[tableView reloadData];
}

-(void)selectAll:(id)sender
{
	[self setAllChecked:YES];
}

-(void)sortItems:(id)sender
{
	BOOL sorted = sortButton.state == NSControlStateValueOn;
	// sort the items under each heading, leaving headings and text in place
	NSUInteger r = 0;
	while ( r < rows.count ) {
		if ( rows[r].item == nil ) {
			++r;
			continue;
		}
		NSUInteger end = r;
		while ( end < rows.count && rows[end].item )
			++end;
		NSRange range = NSMakeRange(r, end - r);
		NSArray * run = [rows subarrayWithRange:range];
		NSArray * ordered;
		if ( sorted ) {
			ordered = [run sortedArrayUsingComparator:^NSComparisonResult(MenuRow * a, MenuRow * b) {
				return [SortKey(a.item.title) localizedCaseInsensitiveCompare:SortKey(b.item.title)];
			}];
		} else {
			NSMutableArray * original = [NSMutableArray array];
			for ( NhItemGroup * group in menuParams.itemGroups ) {
				for ( NhItem * item in group.items ) {
					for ( MenuRow * row in run ) {
						if ( row.item == item )
							[original addObject:row];
					}
				}
			}
			ordered = original;
		}
		[rows replaceObjectsInRange:range withObjectsFromArray:ordered];
		r = end;
	}
	[tableView reloadData];
}

#pragma mark Keys

-(void)installKeyMonitor
{
	__weak MenuWindowController * weakSelf = self;
	keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
		MenuWindowController * strongSelf = weakSelf;
		if ( strongSelf == nil || event.window != strongSelf.window )
			return event;
		return [strongSelf handleKey:event] ? nil : event;
	}];
}

-(NhItem *)itemWithLetter:(unichar)c
{
	for ( MenuRow * row in rows ) {
		if ( row.item && row.item.inventoryLetter == c )
			return row.item;
	}
	return nil;
}

-(BOOL)handleKey:(NSEvent *)event
{
	if ( event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl) )
		return NO;
	NSString * chars = event.characters;
	if ( chars.length == 0 )
		return NO;
	unichar c = [chars characterAtIndex:0];
	NSInteger highlighted = tableView ? tableView.selectedRow : -1;
	NhItem * highlightedItem = highlighted >= 0 ? rows[highlighted].item : nil;

	if ( c == 27 ) {
		[self doCancel:nil];
		return YES;
	}
	if ( c == '\r' || c == 3 ) {
		if ( how == PICK_ONE && highlightedItem )
			[self chooseItem:highlightedItem];
		else
			[self doAccept:nil];
		return YES;
	}
	if ( c == ' ' ) {
		if ( how == PICK_ANY && highlightedItem )
			[self toggleItem:highlightedItem];
		else
			[self doAccept:nil];
		return YES;
	}
	if ( how == PICK_NONE || c > 127 )
		return NO;

	NhItem * item = [self itemWithLetter:c];
	if ( item ) {
		[self chooseItem:item];
		return YES;
	}
	if ( isdigit(c) ) {
		count = count * 10 + (c - '0');
		return YES;
	}
	if ( how == PICK_ANY ) {
		BOOL hit = NO;
		for ( MenuRow * row in rows ) {
			if ( row.item && row.item.group_ch == c ) {
				[checked addObject:row.item];
				hit = YES;
			}
		}
		if ( hit ) {
			[tableView reloadData];
			return YES;
		}
		if ( c == '.' || c == ',' ) {
			[self setAllChecked:YES];
			return YES;
		}
		if ( c == '-' || c == '\\' ) {
			[self setAllChecked:NO];
			return YES;
		}
	}
	return NO;
}

#pragma mark Finishing

-(void)finish
{
	finished = YES;
	if ( keyMonitor ) {
		[NSEvent removeMonitor:keyMonitor];
		keyMonitor = nil;
	}
	[self.window close];
}

-(void)doAccept:(id)sender
{
	if ( finished )
		return;
	[menuParams.selected removeAllObjects];
	for ( MenuRow * row in rows ) {
		if ( row.item && [checked containsObject:row.item] ) {
			row.item.selected = YES;
			[menuParams.selected addObject:row.item];
		}
	}
	if ( how != PICK_NONE )
		[[NhEventQueue instance] addKey:(int)menuParams.selected.count];
	[self finish];
}

-(void)doCancel:(id)sender
{
	if ( finished )
		return;
	if ( how != PICK_NONE )
		[[NhEventQueue instance] addKey:-1];
	[self finish];
}

-(BOOL)windowShouldClose:(id)sender
{
	[self doCancel:sender];
	return NO;
}

-(void)windowWillClose:(NSNotification *)notification
{
	[[NSApplication sharedApplication] stopModal];
}

+ (void)menuWindowWithMenu:(NhMenuWindow *)menu
{
	MenuWindowController * win = [[MenuWindowController alloc] initWithMenu:menu];
	[win showWindow:win];
	[[NSApplication sharedApplication] runModalForWindow:[win window]];
}

@end
