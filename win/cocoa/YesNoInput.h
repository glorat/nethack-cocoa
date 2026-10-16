#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, YesNoResult) {
	YesNoIgnored,
	YesNoBeep,
	YesNoCountChanged,
	YesNoAnswered,
};

// Kept free of AppKit so the tests can run it without a window.
@interface YesNoInput : NSObject

@property (nonatomic, readonly) NSString * answers;
@property (nonatomic, readonly) BOOL allowsCount;
@property (nonatomic, readonly) BOOL counting;
@property (nonatomic, readonly) long count;
@property (nonatomic, readonly) char answer;

+(NSString *)visibleAnswersForChoices:(NSString *)choices;
+(BOOL)canAskWithChoices:(const char *)choices;

-(id)initWithChoices:(NSString *)choices default:(char)def;
-(NSString *)labelForAnswer:(unichar)c;
-(YesNoResult)typeKey:(unichar)c;
-(YesNoResult)pressAnswer:(unichar)c;
-(YesNoResult)cancel;

@end
