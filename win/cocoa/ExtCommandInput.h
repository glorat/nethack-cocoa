#import <Foundation/Foundation.h>

@interface NhExtCommand : NSObject

@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * help;
@property (nonatomic, readonly) BOOL autocompletes;

+(instancetype)commandWithName:(NSString *)name help:(NSString *)help autocompletes:(BOOL)autocompletes;

@end

// Kept free of the core so the tests can run it; the caller passes in extcmdlist.
@interface ExtCommandInput : NSObject

-(id)initWithCommands:(NSArray<NhExtCommand *> *)commands;
-(NSArray<NhExtCommand *> *)listForPrefix:(NSString *)prefix;
-(NSString *)completionOf:(NSString *)typed after:(NSString *)before;
-(NSString *)commandToRunFor:(NSString *)text highlighted:(NhExtCommand *)row;

@end
