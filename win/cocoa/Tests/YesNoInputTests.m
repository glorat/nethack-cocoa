#import <XCTest/XCTest.h>
#import "YesNoInput.h"

@interface YesNoInputTests : XCTestCase
@end

@implementation YesNoInputTests

static YesNoInput * Input(NSString * choices, char def)
{
	return [[YesNoInput alloc] initWithChoices:choices default:def];
}

static YesNoResult Type(YesNoInput * input, NSString * keys)
{
	YesNoResult result = YesNoIgnored;
	for ( NSUInteger i = 0; i < keys.length; ++i )
		result = [input typeKey:[keys characterAtIndex:i]];
	return result;
}

#pragma mark Answers shown

-(void)testVisibleAnswersSkipHiddenChoicesSpacesOrAndCount
{
	XCTAssertEqualObjects([YesNoInput visibleAnswersForChoices:@"yn"], @"yn");
	XCTAssertEqualObjects([YesNoInput visibleAnswersForChoices:@"ynq\033a"], @"ynq");
	XCTAssertEqualObjects([YesNoInput visibleAnswersForChoices:@"yn#aq"], @"ynaq");
	XCTAssertEqualObjects([YesNoInput visibleAnswersForChoices:@"ynq m"], @"ynqm");
	XCTAssertEqualObjects([YesNoInput visibleAnswersForChoices:@":oibrs nq or ?"], @":oibrsnq?");
}

-(void)testOnlyShortAnswerSetsGetADialog
{
	XCTAssertTrue([YesNoInput canAskWithChoices:"yn"]);
	XCTAssertTrue([YesNoInput canAskWithChoices:":oibrs nq or ?"]);
	XCTAssertFalse([YesNoInput canAskWithChoices:NULL]);
	XCTAssertFalse([YesNoInput canAskWithChoices:"q"]);
	XCTAssertFalse([YesNoInput canAskWithChoices:"!?/=\"+([%)*0_`a"]);
}

#pragma mark Labels

-(void)testYesNoAnswersAreNamed
{
	YesNoInput * input = Input(@"ynq m", 'q');
	XCTAssertEqualObjects([input labelForAnswer:'y'], @"Yes");
	XCTAssertEqualObjects([input labelForAnswer:'n'], @"No");
	XCTAssertEqualObjects([input labelForAnswer:'q'], @"Quit");
	XCTAssertEqualObjects([input labelForAnswer:'m'], @"Menu");
	XCTAssertEqualObjects([Input(@"ynaq", 'y') labelForAnswer:'a'], @"All");
}

-(void)testSpecialQuestionsAreNamed
{
	XCTAssertEqualObjects([Input(@":oibrs nq or ?", 'q') labelForAnswer:'o'], @"Take something out");
	XCTAssertEqualObjects([Input(@":oibrs nq or ?", 'q') labelForAnswer:'?'], @"Help");
	XCTAssertEqualObjects([Input(@"rl", 0) labelForAnswer:'l'], @"Left");
	XCTAssertEqualObjects([Input(@"hsq", 0) labelForAnswer:'s'], @"Spin a web");
}

-(void)testOtherAnswerSetsShowTheirOwnCharacters
{
	YesNoInput * byClass = Input(@")[?! uBUCX", 0);
	XCTAssertEqualObjects([byClass labelForAnswer:'?'], @"?");
	XCTAssertEqualObjects([byClass labelForAnswer:'u'], @"u");
	XCTAssertEqualObjects([Input(@"a!?", 0) labelForAnswer:'a'], @"a");
	XCTAssertEqualObjects([Input(@"cnoa q", 'q') labelForAnswer:'n'], @"n");
}

#pragma mark Keys

-(void)testLetterAnswers
{
	YesNoInput * input = Input(@"ynq", 'q');
	XCTAssertEqual([input typeKey:'n'], YesNoAnswered);
	XCTAssertEqual(input.answer, 'n');
}

-(void)testUppercaseIsLoweredUnlessChoicesHaveUppercase
{
	YesNoInput * input = Input(@"hsq", 0);
	XCTAssertEqual([input typeKey:'S'], YesNoAnswered);
	XCTAssertEqual(input.answer, 's');

	input = Input(@"uBUCX", 0);
	XCTAssertEqual([input typeKey:'B'], YesNoAnswered);
	XCTAssertEqual(input.answer, 'B');
}

-(void)testHiddenAnswerIsAccepted
{
	YesNoInput * input = Input(@"ynq\033a", 'n');
	XCTAssertEqual([input typeKey:'a'], YesNoAnswered);
	XCTAssertEqual(input.answer, 'a');
}

-(void)testUnknownKeysBeep
{
	XCTAssertEqual([Input(@"yn", 'n') typeKey:'x'], YesNoBeep);
	XCTAssertEqual([Input(@"yn", 'n') typeKey:'3'], YesNoBeep);
	XCTAssertEqual([Input(@"yn#aq", 'n') typeKey:0xF700], YesNoBeep);
}

-(void)testReturnSpaceAndControlCGiveTheDefault
{
	for ( NSString * key in @[ @"\r", @"\n", @" ", @"\003" ] ) {
		YesNoInput * input = Input(@"yn", 'y');
		XCTAssertEqual(Type(input, key), YesNoAnswered);
		XCTAssertEqual(input.answer, 'y');
	}
}

-(void)testReturnWithoutADefaultAnswersEmpty
{
	YesNoInput * input = Input(@"rl", 0);
	XCTAssertEqual([input typeKey:'\r'], YesNoAnswered);
	XCTAssertEqual(input.answer, 0);
}

-(void)testEscapeAndCloseGiveQuitThenNoThenDefault
{
	YesNoInput * input = Input(@"ynq", 'y');
	XCTAssertEqual([input typeKey:27], YesNoAnswered);
	XCTAssertEqual(input.answer, 'q');

	input = Input(@"yn", 'y');
	XCTAssertEqual([input cancel], YesNoAnswered);
	XCTAssertEqual(input.answer, 'n');

	input = Input(@"rl", 'r');
	XCTAssertEqual([input typeKey:27], YesNoAnswered);
	XCTAssertEqual(input.answer, 'r');
}

-(void)testClickingAnswers
{
	YesNoInput * input = Input(@"ynq", 'q');
	XCTAssertEqual([input pressAnswer:'y'], YesNoAnswered);
	XCTAssertEqual(input.answer, 'y');
}

#pragma mark Counts

-(void)testCountThenReturnTakesThatMany
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	XCTAssertEqual(Type(input, @"12"), YesNoCountChanged);
	XCTAssertTrue(input.counting);
	XCTAssertEqual(Type(input, @"\r"), YesNoAnswered);
	XCTAssertEqual(input.answer, '#');
	XCTAssertEqual(input.count, 12);
}

-(void)testCountThenYTakesThatMany
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	XCTAssertEqual(Type(input, @"#3y"), YesNoAnswered);
	XCTAssertEqual(input.answer, '#');
	XCTAssertEqual(input.count, 3);
}

-(void)testZeroCountAnswersNo
{
	YesNoInput * input = Input(@"yn#aq", 'y');
	XCTAssertEqual(Type(input, @"0\r"), YesNoAnswered);
	XCTAssertEqual(input.answer, 'n');
}

-(void)testBackspaceEditsTheCount
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	XCTAssertEqual(Type(input, @"12\177"), YesNoCountChanged);
	XCTAssertEqual(input.count, 1);
	XCTAssertTrue(input.counting);
}

-(void)testBackspacingTheWholeCountLeavesCounting
{
	YesNoInput * input = Input(@"yn#aq", 'y');
	XCTAssertEqual(Type(input, @"3\177"), YesNoCountChanged);
	XCTAssertFalse(input.counting);
	XCTAssertEqual(Type(input, @"\r"), YesNoAnswered);
	XCTAssertEqual(input.answer, 'y');
}

-(void)testEscapeClearsTheCount
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	XCTAssertEqual(Type(input, @"4\033"), YesNoCountChanged);
	XCTAssertFalse(input.counting);
	XCTAssertEqual(input.count, 0);
}

-(void)testOtherAnswerKeyWhileCountingBeepsAndDropsTheCount
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	XCTAssertEqual(Type(input, @"4a"), YesNoBeep);
	XCTAssertFalse(input.counting);
	XCTAssertEqual(input.count, 0);
}

-(void)testClickingYesWhileCountingTakesThatMany
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	Type(input, @"3");
	XCTAssertEqual([input pressAnswer:'y'], YesNoAnswered);
	XCTAssertEqual(input.answer, '#');
	XCTAssertEqual(input.count, 3);
}

-(void)testClickingAnotherAnswerWhileCountingIgnoresTheCount
{
	YesNoInput * input = Input(@"yn#aq", 'n');
	Type(input, @"3");
	XCTAssertEqual([input pressAnswer:'a'], YesNoAnswered);
	XCTAssertEqual(input.answer, 'a');
}

@end
