#import "ExtCommandInput.h"

@implementation NhExtCommand

+(instancetype)commandWithName:(NSString *)name help:(NSString *)help autocompletes:(BOOL)autocompletes
{
	NhExtCommand * command = [[NhExtCommand alloc] init];
	command->_name = [name copy];
	command->_help = [help copy];
	command->_autocompletes = autocompletes;
	return command;
}

@end

@implementation ExtCommandInput {
	NSArray<NhExtCommand *> *	commands;
}

-(id)initWithCommands:(NSArray<NhExtCommand *> *)theCommands
{
	if ( self = [super init] )
		commands = [theCommands copy];
	return self;
}

-(NSArray<NhExtCommand *> *)listForPrefix:(NSString *)prefix
{
	NSMutableArray * list = [NSMutableArray array];
	for ( NhExtCommand * command in commands ) {
		if ( command.autocompletes && command.name.length > 1
			&& (prefix.length == 0 || [command.name rangeOfString:prefix options:NSAnchoredSearch | NSCaseInsensitiveSearch].location != NSNotFound) )
			[list addObject:command];
	}
	return list;
}

// as tty, a prefix only one command starts with completes to it, but not while deleting
-(NSString *)completionOf:(NSString *)typed after:(NSString *)before
{
	if ( typed.length <= before.length || typed.length == 0 )
		return nil;
	NSArray * list = [self listForPrefix:typed];
	return list.count == 1 ? [list.firstObject name] : nil;
}

-(NSString *)commandToRunFor:(NSString *)text highlighted:(NhExtCommand *)row
{
	text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	for ( NhExtCommand * command in commands ) {
		if ( [command.name caseInsensitiveCompare:text] == NSOrderedSame )
			return command.name;
	}
	return row ? row.name : text;
}

@end
