#import <XCTest/XCTest.h>
#import "OptionsFile.h"

@interface OptionsFileTests : XCTestCase
@end

@implementation OptionsFileTests
{
	NSString * folder;
}

-(void)setUp
{
	folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
}

-(void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
}

-(NSString *)contentsOf:(NSString *)path
{
	return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

-(void)testAMissingFileStartsFromTheTemplate
{
	NSString * path = [folder stringByAppendingPathComponent:@".nethackrc"];
	XCTAssertTrue(NhCreateOptionsFile(path, NULL));
	XCTAssertEqualObjects([self contentsOf:path], NhOptionsFileTemplate());
}

-(void)testAnExistingFileIsLeftAlone
{
	NSString * path = [folder stringByAppendingPathComponent:@".nethackrc"];
	[@"OPTIONS=autodig\n" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertTrue(NhCreateOptionsFile(path, NULL));
	XCTAssertEqualObjects([self contentsOf:path], @"OPTIONS=autodig\n");
}

// gameplay options are the player's, so the template only suggests them
-(void)testTheTemplateSetsNothing
{
	for ( NSString * line in [NhOptionsFileTemplate() componentsSeparatedByString:@"\n"] )
		XCTAssertTrue(line.length == 0 || [line hasPrefix:@"#"], @"%@", line);
}

@end
