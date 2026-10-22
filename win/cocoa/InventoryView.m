//
//  InventoryView.m
//  NetHack
//

#import "InventoryView.h"
#import "NhItem.h"
#import "NhItemGroup.h"
#import "TileSet.h"
#import "NhTextStyle.h"
#import "TextSize.h"

static const CGFloat kTileSize		= 24.0;
static const CGFloat kMargin		= 10.0;

@interface InventoryResizeHandle : NSView
@property (nonatomic, weak) InventoryView * sidebar;
@end

@implementation InventoryResizeHandle

- (void)resetCursorRects
{
	[self addCursorRect:self.bounds cursor:[NSCursor resizeLeftRightCursor]];
}

- (void)mouseDown:(NSEvent *)event
{
	InventoryView * sidebar = self.sidebar;
	CGFloat startX = event.locationInWindow.x;
	CGFloat startWidth = sidebar.frame.size.width;
	for ( ;; ) {
		event = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
		BOOL done = event.type == NSEventTypeLeftMouseUp;
		if ( sidebar.resize )
			sidebar.resize(startWidth + startX - event.locationInWindow.x, done);
		if ( done )
			break;
	}
}

@end


@implementation InventoryView
{
	NSTableView		*	tableView;
	NSMutableArray	*	rows;	// NSAttributedString for a heading, NhItem for an item
	NSArray<NhItemGroup *> *	groups;
}

- (instancetype)initWithFrame:(NSRect)frame
{
	if ( self = [super initWithFrame:frame] ) {
		rows = [NSMutableArray array];

		NSScrollView * scrollView = [[NSScrollView alloc] init];
		scrollView.translatesAutoresizingMaskIntoConstraints = NO;
		scrollView.hasVerticalScroller = YES;
		scrollView.autohidesScrollers = YES;
		scrollView.borderType = NSNoBorder;
		[self addSubview:scrollView];

		tableView = [[NSTableView alloc] init];
		NSTableColumn * column = [[NSTableColumn alloc] initWithIdentifier:@"inventory"];
		column.resizingMask = NSTableColumnAutoresizingMask;
		[tableView addTableColumn:column];
		tableView.headerView = nil;
		tableView.style = NSTableViewStylePlain;
		tableView.intercellSpacing = NSMakeSize(0, 2);
		tableView.allowsTypeSelect = NO;
		tableView.allowsEmptySelection = YES;
		tableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
		tableView.refusesFirstResponder = YES;
		tableView.dataSource = self;
		tableView.delegate = self;
		tableView.target = self;
		tableView.action = @selector(rowClicked:);
		scrollView.documentView = tableView;

		NSBox * divider = [[NSBox alloc] init];
		divider.boxType = NSBoxSeparator;
		divider.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:divider];

		InventoryResizeHandle * handle = [[InventoryResizeHandle alloc] init];
		handle.sidebar = self;
		handle.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:handle];

		[NSLayoutConstraint activateConstraints:@[
			[handle.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[handle.topAnchor constraintEqualToAnchor:self.topAnchor],
			[handle.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
			[handle.widthAnchor constraintEqualToConstant:5],
			[divider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[divider.topAnchor constraintEqualToAnchor:self.topAnchor],
			[divider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
			[divider.widthAnchor constraintEqualToConstant:1],
			[scrollView.leadingAnchor constraintEqualToAnchor:divider.trailingAnchor],
			[scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
			[scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
		]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTextSize)
			name:NhTextSizeDidChangeNotification object:nil];
	}
	return self;
}

-(void)applyTextSize
{
	[self setItemGroups:groups];
}

-(NSFont *)itemFont
{
	return [NSFont systemFontOfSize:NhScaledFontSize(13)];
}

- (void)setItemGroups:(NSArray<NhItemGroup *> *)itemGroups
{
	groups = itemGroups;
	[rows removeAllObjects];
	for ( NhItemGroup * group in groups ) {
		if ( !group.dummy && group.title.length ) {
			NSString * title = [group.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSDictionary * attributes = NhTextAttributes(group.color, ATR_NONE, [NSFont systemFontOfSize:NhScaledFontSize(13) weight:NSFontWeightSemibold]);
			[rows addObject:[[NSAttributedString alloc] initWithString:title attributes:attributes]];
		}
		[rows addObjectsFromArray:group.items];
	}
	[tableView reloadData];
}

- (void)rowClicked:(id)sender
{
	NSInteger r = tableView.clickedRow;
	[tableView deselectAll:nil];
	if ( r < 0 || ![rows[r] isKindOfClass:[NhItem class]] )
		return;
	NhItem * item = rows[r];
	if ( item.inventoryLetter && self.chooseItem )
		self.chooseItem(item.inventoryLetter);
}

#pragma mark Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
	return rows.count;
}

- (BOOL)tableView:(NSTableView *)tv isGroupRow:(NSInteger)r
{
	return ![rows[r] isKindOfClass:[NhItem class]];
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)r
{
	return [rows[r] isKindOfClass:[NhItem class]];
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)r
{
	CGFloat text = NhLineHeight([self itemFont]);
	return [rows[r] isKindOfClass:[NhItem class]] ? MAX(kTileSize, text) + 4 : text + 6;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)column row:(NSInteger)r
{
	NSTableCellView * cell = [[NSTableCellView alloc] init];
	if ( ![rows[r] isKindOfClass:[NhItem class]] ) {
		NSTextField * label = [NSTextField labelWithAttributedString:rows[r]];
		label.translatesAutoresizingMaskIntoConstraints = NO;
		[cell addSubview:label];
		[NSLayoutConstraint activateConstraints:@[
			[label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:kMargin],
			[label.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-kMargin],
			[label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		]];
		return cell;
	}

	NhItem * item = rows[r];
	NSImageView * tile = [[NSImageView alloc] init];
	tile.translatesAutoresizingMaskIntoConstraints = NO;
	tile.imageScaling = NSImageScaleProportionallyUpOrDown;
	if ( item.glyph != NO_GLYPH )
		tile.image = [[TileSet instance] imageForGlyph:item.glyph enabled:YES];

	NSTextField * letter = [NSTextField labelWithString:item.inventoryLetter ? [NSString stringWithFormat:@"%c", item.inventoryLetter] : @""];
	letter.font = [NSFont monospacedSystemFontOfSize:NhScaledFontSize(13) weight:NSFontWeightMedium];
	letter.textColor = [NSColor secondaryLabelColor];
	letter.translatesAutoresizingMaskIntoConstraints = NO;

	NSString * text = [item.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ( item.detail )
		text = [text stringByAppendingFormat:@" (%@)", item.detail];
	NSMutableParagraphStyle * style = [[NSMutableParagraphStyle alloc] init];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	NSMutableDictionary * attributes = [NhTextAttributes(item.color, item.attr, [self itemFont]) mutableCopy];
	attributes[NSParagraphStyleAttributeName] = style;
	NSTextField * name = [NSTextField labelWithAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
	name.lineBreakMode = NSLineBreakByTruncatingTail;
	name.toolTip = text;
	name.translatesAutoresizingMaskIntoConstraints = NO;
	[name setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

	[cell addSubview:tile];
	[cell addSubview:letter];
	[cell addSubview:name];
	cell.textField = name;
	[NSLayoutConstraint activateConstraints:@[
		[tile.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:kMargin],
		[tile.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		[tile.widthAnchor constraintEqualToConstant:kTileSize],
		[tile.heightAnchor constraintEqualToConstant:kTileSize],
		[letter.leadingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:6],
		[letter.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
		[name.leadingAnchor constraintEqualToAnchor:letter.leadingAnchor constant:NhScaledFontSize(18)],
		[name.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-kMargin],
		[name.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
	]];
	return cell;
}

@end
