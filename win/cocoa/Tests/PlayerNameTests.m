#import <XCTest/XCTest.h>
#import "PlayerName.h"

@interface PlayerNameTests : XCTestCase
@end

@implementation PlayerNameTests

static NSString * Name(const char * typed, BOOL * ok)
{
	char name[32];
	memset(name, 'X', sizeof name);
	BOOL given = NhPlayerName(typed, name, sizeof name);
	if ( ok )
		*ok = given;
	return given ? @(name) : nil;
}

-(void)testLettersAreKept
{
	XCTAssertEqualObjects(Name("Lancelot", NULL), @"Lancelot");
}

-(void)testSpacesAndPunctuationBecomeUnderscores
{
	XCTAssertEqualObjects(Name("Sir Lancelot!", NULL), @"Sir_Lancelot_");
	XCTAssertEqualObjects(Name("a/b.c", NULL), @"a_b_c");
}

-(void)testHyphenAndAtSignAreKept
{
	XCTAssertEqualObjects(Name("Jean-Luc@home", NULL), @"Jean-Luc@home");
}

-(void)testDigitsAreKeptExceptAtTheStart
{
	XCTAssertEqualObjects(Name("7of9", NULL), @"_of9");
}

-(void)testALongNameIsCutToFit
{
	XCTAssertEqualObjects(Name("abcdefghijklmnopqrstuvwxyzabcdefghijklmnop", NULL), @"abcdefghijklmnopqrstuvwxyzabcde");
}

-(void)testNothingTypedGivesNoName
{
	BOOL ok = YES;
	Name("", &ok);
	XCTAssertFalse(ok);
}

-(void)testCancellingGivesNoName
{
	BOOL ok = YES;
	Name("\033", &ok);
	XCTAssertFalse(ok);
}

@end
