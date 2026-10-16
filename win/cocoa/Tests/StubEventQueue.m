#import "StubEventQueue.h"

static NSMutableArray<NSNumber *> * sentKeys;

@implementation StubEventQueue

+(void)reset
{
	sentKeys = [NSMutableArray array];
}

+(NSArray<NSNumber *> *)keys
{
	return [sentKeys copy];
}

@end

@implementation NhEventQueue

+(NhEventQueue *)instance
{
	static NhEventQueue * queue;
	if ( queue == nil )
		queue = [[NhEventQueue alloc] init];
	return queue;
}

-(void)addKey:(int)k
{
	[sentKeys addObject:@(k)];
}

-(void)addEvent:(NhEvent *)e {}
-(void)addEscapeKey {}
-(void)addKeys:(const char *)keys {}
-(void)addCommand:(NhCommand *)cmd {}
-(NhEvent *)nextEvent { return nil; }
-(void)waitForNextEvent {}
-(NhEvent *)peek { return nil; }

@end
