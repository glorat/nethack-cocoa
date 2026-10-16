#import <XCTest/XCTest.h>
#import "ExtCommandInput.h"

@interface ExtCommandInputTests : XCTestCase
@end

@implementation ExtCommandInputTests {
	ExtCommandInput * input;
}

static NhExtCommand * Cmd(NSString * name, BOOL autocompletes)
{
	return [NhExtCommand commandWithName:name help:[name stringByAppendingString:@" help"] autocompletes:autocompletes];
}

-(void)setUp
{
	input = [[ExtCommandInput alloc] initWithCommands:@[
		Cmd(@"?", YES), Cmd(@"adjust", YES), Cmd(@"loot", YES), Cmd(@"offer", YES),
		Cmd(@"overview", YES), Cmd(@"pray", YES), Cmd(@"ride", YES), Cmd(@"terrain", NO),
	]];
}

static NSArray * Names(NSArray<NhExtCommand *> * list)
{
	return [list valueForKey:@"name"];
}

#pragma mark List

-(void)testEmptyPrefixListsEveryAutocompleteCommand
{
	XCTAssertEqualObjects(Names([input listForPrefix:@""]), (@[ @"adjust", @"loot", @"offer", @"overview", @"pray", @"ride" ]));
}

-(void)testPrefixFiltersIgnoringCase
{
	XCTAssertEqualObjects(Names([input listForPrefix:@"o"]), (@[ @"offer", @"overview" ]));
	XCTAssertEqualObjects(Names([input listForPrefix:@"PR"]), (@[ @"pray" ]));
}

-(void)testCommandsWithoutAutocompleteAreNotListed
{
	XCTAssertEqualObjects(Names([input listForPrefix:@"ter"]), (@[]));
}

#pragma mark Completion

-(void)testAUniquePrefixCompletes
{
	XCTAssertEqualObjects([input completionOf:@"p" after:@""], @"pray");
	XCTAssertEqualObjects([input completionOf:@"of" after:@"o"], @"offer");
	XCTAssertEqualObjects([input completionOf:@"PR" after:@"P"], @"pray");
}

-(void)testAnAmbiguousPrefixDoesNotComplete
{
	XCTAssertNil([input completionOf:@"o" after:@""]);
}

-(void)testDeletingDoesNotComplete
{
	XCTAssertNil([input completionOf:@"pr" after:@"pra"]);
}

-(void)testCommandsWithoutAutocompleteDoNotComplete
{
	XCTAssertNil([input completionOf:@"te" after:@"t"]);
}

#pragma mark Running

-(void)testAnExactNameRunsIgnoringCaseAndSpaces
{
	XCTAssertEqualObjects([input commandToRunFor:@"pray" highlighted:nil], @"pray");
	XCTAssertEqualObjects([input commandToRunFor:@" PRAY " highlighted:nil], @"pray");
}

-(void)testAnExactNameRunsEvenWithoutAutocomplete
{
	XCTAssertEqualObjects([input commandToRunFor:@"terrain" highlighted:nil], @"terrain");
}

-(void)testAnExactNameBeatsTheHighlightedRow
{
	XCTAssertEqualObjects([input commandToRunFor:@"loot" highlighted:Cmd(@"offer", YES)], @"loot");
}

-(void)testOtherwiseTheHighlightedRowRuns
{
	XCTAssertEqualObjects([input commandToRunFor:@"o" highlighted:Cmd(@"offer", YES)], @"offer");
	XCTAssertEqualObjects([input commandToRunFor:@"" highlighted:Cmd(@"ride", YES)], @"ride");
}

-(void)testNothingTypedOrHighlightedCancels
{
	XCTAssertEqualObjects([input commandToRunFor:@"" highlighted:nil], @"");
}

-(void)testUnknownTextGoesToTheGameToReject
{
	XCTAssertEqualObjects([input commandToRunFor:@"xyz" highlighted:nil], @"xyz");
}

@end
