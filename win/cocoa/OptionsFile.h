#import <Foundation/Foundation.h>

// What a new options file starts with
NSString * NhOptionsFileTemplate(void);

// Writes the template to path unless a file is already there
BOOL NhCreateOptionsFile(NSString * path, NSError ** error);
