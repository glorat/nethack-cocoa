#import "YesNoInput.h"

@implementation YesNoInput {
	NSString *	choices;
	NSString *	accepted;
	char		def;
	BOOL		preserveCase;
	int			digits;
}

// pickup.c appends " or ?" to the choices, so "or" is a word, not two answers
+(NSString *)visibleAnswersForChoices:(NSString *)choices
{
	NSString * shown = [choices componentsSeparatedByString:@"\033"].firstObject;
	NSMutableString * answers = [NSMutableString string];
	for ( NSString * word in [shown componentsSeparatedByString:@" "] ) {
		if ( [word isEqualToString:@"or"] )
			continue;
		for ( NSUInteger i = 0; i < word.length; ++i ) {
			NSString * c = [word substringWithRange:NSMakeRange(i, 1)];
			if ( ![c isEqualToString:@"#"] && ![answers containsString:c] )
				[answers appendString:c];
		}
	}
	return answers;
}

+(BOOL)canAskWithChoices:(const char *)choices
{
	if ( choices == NULL )
		return NO;
	NSUInteger n = [self visibleAnswersForChoices:[NSString stringWithCString:choices encoding:NSASCIIStringEncoding]].length;
	return n >= 2 && n <= 9;
}

-(id)initWithChoices:(NSString *)theChoices default:(char)theDefault
{
	if ( self = [super init] ) {
		choices = [theChoices copy];
		def = theDefault;
		_answers = [YesNoInput visibleAnswersForChoices:choices];
		accepted = [[choices stringByReplacingOccurrencesOfString:@" " withString:@""]
					stringByReplacingOccurrencesOfString:@"\033" withString:@""];
		preserveCase = [choices rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound;
		_allowsCount = [choices containsString:@"#"];
	}
	return self;
}

-(NSString *)labelForAnswer:(unichar)c
{
	NSDictionary * labels;
	if ( [choices containsString:@":"] ) {
		labels = @{ @":" : @"Look inside", @"o" : @"Take something out", @"i" : @"Put something in",
					@"b" : @"Both: take out, then put in", @"r" : @"Reversed: put in, then take out",
					@"s" : @"Stash one item", @"n" : @"Next container", @"q" : @"Quit", @"?" : @"Help" };
	} else if ( [choices isEqualToString:@"rl"] ) {
		labels = @{ @"r" : @"Right", @"l" : @"Left" };
	} else if ( [choices isEqualToString:@"ynr"] ) {
		labels = @{ @"y" : @"Destroy", @"r" : @"Recover", @"n" : @"Cancel" };
	} else if ( [choices hasPrefix:@"hs"] ) {
		labels = @{ @"h" : @"Hide", @"s" : @"Spin a web", @"q" : @"Quit" };
	} else if ( [_answers rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ynaqm"] invertedSet]].location == NSNotFound ) {
		labels = @{ @"y" : @"Yes", @"n" : @"No", @"a" : @"All", @"q" : @"Quit", @"m" : @"Menu" };
	}
	NSString * key = [NSString stringWithCharacters:&c length:1];
	return labels[key] ?: key;
}

-(BOOL)accepts:(unichar)c
{
	return c < 128 && [accepted rangeOfString:[NSString stringWithCharacters:&c length:1]].location != NSNotFound;
}

-(YesNoResult)answerWith:(char)c
{
	_answer = c;
	return YesNoAnswered;
}

-(char)escapeAnswer
{
	if ( [accepted containsString:@"q"] )
		return 'q';
	if ( [accepted containsString:@"n"] )
		return 'n';
	return def;
}

-(YesNoResult)finishCount
{
	return [self answerWith:_count > 0 ? '#' : 'n'];
}

-(void)stopCounting
{
	_counting = NO;
	_count = 0;
	digits = 0;
}

-(YesNoResult)typeKey:(unichar)c
{
	if ( !preserveCase && c < 128 )
		c = tolower(c);

	if ( _allowsCount && c < 128 && (isdigit(c) || c == '#') ) {
		_counting = YES;
		if ( c != '#' && _count < 100000000 ) {
			_count = _count * 10 + (c - '0');
			++digits;
		}
		return YesNoCountChanged;
	}
	if ( _counting && (c == 127 || c == 8) ) {
		_count /= 10;
		if ( --digits <= 0 )
			[self stopCounting];
		return YesNoCountChanged;
	}
	if ( c == 27 ) {
		if ( _counting ) {
			[self stopCounting];
			return YesNoCountChanged;
		}
		return [self answerWith:[self escapeAnswer]];
	}
	if ( c == '\r' || c == '\n' || c == ' ' || c == 3 || (_counting && c == 'y') ) {
		if ( _counting )
			return [self finishCount];
		return [self answerWith:def];
	}
	if ( _counting ) {
		[self stopCounting];
		return YesNoBeep;
	}
	if ( [self accepts:c] )
		return [self answerWith:(char)c];
	return YesNoBeep;
}

-(YesNoResult)pressAnswer:(unichar)c
{
	if ( _counting && c == 'y' )
		return [self finishCount];
	return [self answerWith:(char)c];
}

-(YesNoResult)cancel
{
	return [self answerWith:[self escapeAnswer]];
}

@end
