#import <Carbon/Carbon.h>
#import "WindowTestCase.h"
#import "ExtCommandWindowController.h"
#import "ExtCommandInput.h"

@interface ExtCommandWindowTests : WindowTestCase
@end

@implementation ExtCommandWindowTests {
	NSString * answer;
	NSUInteger answers;
}

-(void)ask:(NSArray<void (^)(void)> *)steps
{
	[self ask:steps extra:@[]];
}

-(void)ask:(NSArray<void (^)(void)> *)steps extra:(NSArray *)extra
{
	answer = nil;
	answers = 0;
	NSArray * commands = [extra arrayByAddingObjectsFromArray:@[
		[NhExtCommand commandWithName:@"loot" help:@"loot a box on the floor" autocompletes:YES],
		[NhExtCommand commandWithName:@"offer" help:@"offer a sacrifice to the gods" autocompletes:YES],
		[NhExtCommand commandWithName:@"overview" help:@"show a summary of the dungeon" autocompletes:YES],
		[NhExtCommand commandWithName:@"pray" help:@"pray to the gods for help" autocompletes:YES],
		[NhExtCommand commandWithName:@"terrain" help:@"view map without monsters or objects" autocompletes:NO],
	]];
	[self runModal:^{
		[ExtCommandWindowController askWithCommands:commands answer:^(NSString * command) {
			self->answer = command;
			self->answers++;
		}];
	} steps:steps];
}


static void Type(NSString * text)
{
	for ( NSUInteger i = 0; i < text.length; ++i )
		SendKey([text substringWithRange:NSMakeRange(i, 1)], 0, 0);
}

static void Return(void) { SendKey(@"\r", 0, kVK_Return); }

static NSTableView * Table(void)
{
	NSMutableArray * views = [NSMutableArray arrayWithObject:TestDialog().contentView];
	while ( views.count ) {
		NSView * view = views.lastObject;
		[views removeLastObject];
		if ( [view isKindOfClass:[NSTableView class]] )
			return (NSTableView *)view;
		[views addObjectsFromArray:view.subviews];
	}
	return nil;
}

-(void)assertAnswer:(NSString *)expected
{
	XCTAssertEqualObjects(answer, expected);
	XCTAssertEqual(answers, 1u);
}

-(void)testTypingANameAndReturnRunsIt
{
	[self ask:@[ ^{ Type(@"loot"); }, ^{ Return(); } ]];
	[self assertAnswer:@"loot"];
}

-(void)testAUniquePrefixAndReturnRunsTheCompletedCommand
{
	[self ask:@[ ^{ Type(@"pr"); }, ^{ Return(); } ]];
	[self assertAnswer:@"pray"];
}

-(void)testTheCompletionIsShownAfterTheCursor
{
	__block NSString * shown = nil;
	__block NSRange selected = { 0, 0 };
	[self ask:@[ ^{ Type(@"p"); }, ^{
		NSText * editor = (NSText *)TestDialog().firstResponder;
		shown = [editor.string copy];
		selected = editor.selectedRange;
	}, ^{ SendKey(@"\033", 0, kVK_Escape); }, ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	XCTAssertEqualObjects(shown, @"pray");
	XCTAssertEqual(selected.location, 1u);
	XCTAssertEqual(selected.length, 3u);
}

-(void)testBackspaceRemovesTheCompletion
{
	__block NSString * shown = nil;
	[self ask:@[ ^{ Type(@"pr"); }, ^{ SendKey(@"\177", 0, kVK_Delete); }, ^{
		shown = [((NSText *)TestDialog().firstResponder).string copy];
	}, ^{ SendKey(@"\033", 0, kVK_Escape); }, ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	XCTAssertEqualObjects(shown, @"pr");
}

-(void)testAnAmbiguousPrefixRunsTheHighlightedFirstMatch
{
	[self ask:@[ ^{ Type(@"o"); }, ^{ Return(); } ]];
	[self assertAnswer:@"offer"];
}

-(void)testDownArrowMovesTheHighlight
{
	[self ask:@[ ^{ Type(@"o"); }, ^{ SendKey([NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey], NSEventModifierFlagFunction, kVK_DownArrow); }, ^{ Return(); } ]];
	[self assertAnswer:@"overview"];
}

-(void)testACommandWithoutAutocompleteRunsWhenTypedInFull
{
	[self ask:@[ ^{ Type(@"terrain"); }, ^{ Return(); } ]];
	[self assertAnswer:@"terrain"];
}

-(void)testReturnWithNothingTypedCancels
{
	[self ask:@[ ^{ Return(); } ]];
	[self assertAnswer:@""];
}

-(void)testEscapeWithTextTypedClearsItFirst
{
	__block NSString * shown = nil;
	__block NSUInteger answersAfterFirstEscape = 99;
	[self ask:@[ ^{ Type(@"ofer"); }, ^{ SendKey(@"\033", 0, kVK_Escape); }, ^{
		shown = [((NSText *)TestDialog().firstResponder).string copy];
		answersAfterFirstEscape = self->answers;
	}, ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	XCTAssertEqualObjects(shown, @"");
	XCTAssertEqual(answersAfterFirstEscape, 0u);
	[self assertAnswer:@""];
}

-(void)testEscapeWithNothingTypedCancels
{
	[self ask:@[ ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	[self assertAnswer:@""];
}

-(void)testCloseButtonCancels
{
	[self ask:@[ ^{ [TestDialog() performClose:nil]; } ]];
	[self assertAnswer:@""];
}

-(void)testALongNameAndDescriptionFitOnOneLine
{
	NhExtCommand * longest = [NhExtCommand commandWithName:@"therecmdmenu" help:@"list monsters that have been genocided or become extinct" autocompletes:YES];
	__block NSSize needed = NSZeroSize, cell = NSZeroSize;
	__block NSTextTab * tab = nil;
	__block CGFloat nameWidth = 0;
	[self ask:@[ ^{
		[Table().window layoutIfNeeded];
		NSTableCellView * view = [Table() viewAtColumn:0 row:0 makeIfNecessary:YES];
		NSAttributedString * text = view.textField.attributedStringValue;
		needed = [text boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin].size;
		cell = view.textField.frame.size;
		NSParagraphStyle * style = [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
		tab = style.tabStops.firstObject;
		nameWidth = [[text attributedSubstringFromRange:NSMakeRange(0, 12)] size].width;
	}, ^{ SendKey(@"\033", 0, kVK_Escape); } ] extra:@[ longest ]];
	XCTAssertLessThanOrEqual(needed.width, cell.width, @"the row is wider than its cell, so it wraps or is cut off");
	XCTAssertGreaterThan(tab.location, nameWidth, @"the description starts inside the name");
}

-(void)testListShowsEachAutocompleteCommandWithItsHelp
{
	__block NSArray * rows = nil;
	[self ask:@[ ^{
		NSTableView * table = nil;
		NSMutableArray * views = [NSMutableArray arrayWithObject:TestDialog().contentView];
		while ( views.count ) {
			NSView * view = views.lastObject;
			[views removeLastObject];
			if ( [view isKindOfClass:[NSTableView class]] )
				table = (NSTableView *)view;
			[views addObjectsFromArray:view.subviews];
		}
		NSMutableArray * texts = [NSMutableArray array];
		for ( NSInteger r = 0; r < table.numberOfRows; ++r ) {
			NSTableCellView * cell = [table viewAtColumn:0 row:r makeIfNecessary:YES];
			[texts addObject:cell.textField.stringValue];
		}
		rows = texts;
	}, ^{ SendKey(@"\033", 0, kVK_Escape); } ]];
	XCTAssertEqual(rows.count, 4u);
	XCTAssertTrue([rows.firstObject hasPrefix:@"loot"]);
	XCTAssertTrue([rows.firstObject containsString:@"loot a box on the floor"]);
}

@end
