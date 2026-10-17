//
//  InventoryView.m
//  NetHack
//

#import "InventoryView.h"
#import "NhItem.h"
#import "NhItemGroup.h"
#import "TileSet.h"

static const CGFloat kTileSize		= 24.0;
static const CGFloat kMargin		= 10.0;

@implementation InventoryView
{
	NSTableView		*	tableView;
	NSMutableArray	*	rows;	// NSString for a heading, NhItem for an item
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

		[NSLayoutConstraint activateConstraints:@[
			[divider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[divider.topAnchor constraintEqualToAnchor:self.topAnchor],
			[divider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
			[divider.widthAnchor constraintEqualToConstant:1],
			[scrollView.leadingAnchor constraintEqualToAnchor:divider.trailingAnchor],
			[scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[scrollView.topAnchor constraintEqualToAnchor:self.topAnchor],
			[scrollView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
		]];
	}
	return self;
}

- (void)setItemGroups:(NSArray<NhItemGroup *> *)groups
{
	[rows removeAllObjects];
	for ( NhItemGroup * group in groups ) {
		if ( !group.dummy && group.title.length )
			[rows addObject:[group.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
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
	return [rows[r] isKindOfClass:[NSString class]];
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)r
{
	return [rows[r] isKindOfClass:[NhItem class]];
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)r
{
	return [rows[r] isKindOfClass:[NhItem class]] ? kTileSize + 4 : 22;
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)column row:(NSInteger)r
{
	NSTableCellView * cell = [[NSTableCellView alloc] init];
	if ( [rows[r] isKindOfClass:[NSString class]] ) {
		NSTextField * label = [NSTextField labelWithString:rows[r]];
		label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
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
	letter.font = [NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightMedium];
	letter.textColor = [NSColor secondaryLabelColor];
	letter.translatesAutoresizingMaskIntoConstraints = NO;

	NSString * text = [item.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ( item.detail )
		text = [text stringByAppendingFormat:@" (%@)", item.detail];
	NSTextField * name = [NSTextField labelWithString:text];
	name.font = [NSFont systemFontOfSize:13];
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
		[name.leadingAnchor constraintEqualToAnchor:tile.trailingAnchor constant:24],
		[name.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-kMargin],
		[name.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
	]];
	return cell;
}

@end
