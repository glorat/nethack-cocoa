#import <XCTest/XCTest.h>

@interface MenuCommandTests : XCTestCase
@end

@implementation MenuCommandTests

static NSArray<NSXMLElement *> * GameMenuItems(void)
{
	NSString * path = [@COCOA_SOURCE_DIR stringByAppendingPathComponent:@"en.lproj/MainMenu.xib"];
	NSXMLDocument * xib = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:0 error:NULL];
	return [xib nodesForXPath:@"//menuItem[connections/action/@selector='performMenuAction:']" error:NULL];
}

static NSSet<NSString *> * CoreCommandNames(void)
{
	NSString * path = [@COCOA_SOURCE_DIR stringByAppendingPathComponent:@"../../src/cmd.c"];
	NSString * source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
	NSRange start = [source rangeOfString:@"struct ext_func_tab extcmdlist[] = {"];
	NSString * table = [source substringWithRange:NSMakeRange(start.location, [source rangeOfString:@"};" options:0 range:NSMakeRange(start.location, source.length - start.location)].location - start.location)];
	NSRegularExpression * entry = [NSRegularExpression regularExpressionWithPattern:@"\\{\\s*(?:'(?:\\\\[0-7]{1,3}|\\\\.|[^'])'|[A-Z_]+|[CM]\\('.'\\)),\\s*\"([^\"]+)\"" options:0 error:NULL];
	NSMutableSet * names = [NSMutableSet set];
	for ( NSTextCheckingResult * match in [entry matchesInString:table options:0 range:NSMakeRange(0, table.length)] )
		[names addObject:[table substringWithRange:[match rangeAtIndex:1]]];
	return names;
}

static NSString * Title(NSXMLElement * item)
{
	return [item attributeForName:@"title"].stringValue;
}

-(void)testTheCoreCommandListIsRead
{
	NSSet * names = CoreCommandNames();
	for ( NSString * name in @[ @"pray", @"seeamulet", @"pickup", @"terrain", @"movenorth" ] )
		XCTAssertTrue([names containsObject:name], @"%@", name);
	XCTAssertGreaterThan(GameMenuItems().count, 80u);
}

-(void)testWizardModeStartsHidden
{
	NSString * path = [@COCOA_SOURCE_DIR stringByAppendingPathComponent:@"en.lproj/MainMenu.xib"];
	NSXMLDocument * xib = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:0 error:NULL];
	NSXMLElement * wizard = [[xib nodesForXPath:@"//menuItem[@title='Wizard Mode']" error:NULL] firstObject];
	XCTAssertEqualObjects([wizard attributeForName:@"hidden"].stringValue, @"YES");
}

-(void)testEveryGameMenuItemNamesACommand
{
	for ( NSXMLElement * item in GameMenuItems() )
		XCTAssertNotNil([item attributeForName:@"identifier"], @"\"%@\" doesn't name its command", Title(item));
}

-(void)testEveryNamedCommandExistsInTheCore
{
	NSSet * names = CoreCommandNames();
	for ( NSXMLElement * item in GameMenuItems() ) {
		NSString * command = [item attributeForName:@"identifier"].stringValue;
		if ( command )
			XCTAssertTrue([names containsObject:command], @"\"%@\" names \"%@\", which NetHack doesn't have", Title(item), command);
	}
}

-(void)testNoCommandIsInTheMenuTwice
{
	NSCountedSet * commands = [NSCountedSet set];
	for ( NSXMLElement * item in GameMenuItems() ) {
		NSString * command = [item attributeForName:@"identifier"].stringValue;
		if ( command )
			[commands addObject:command];
	}
	for ( NSString * command in commands )
		XCTAssertEqual([commands countForObject:command], 1u, @"\"%@\" is in the menu more than once", command);
}

@end
