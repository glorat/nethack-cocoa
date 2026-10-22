#import "OptionsFile.h"

NSString * NhOptionsFileTemplate(void)
{
	return
		@"# NetHack options. Lines starting with # are ignored.\n"
		@"# Changes take effect when you start a new game. A saved game keeps\n"
		@"# most of its own options; change those with Game > Options instead,\n"
		@"# which also lists every option and its current value.\n"
		@"#\n"
		@"# The app already shows the turn count and experience points, colors\n"
		@"# menus, and marks your pet and item piles, so those needn't be set here.\n"
		@"#\n"
		@"# Some options players often change; remove the # to use one:\n"
		@"#OPTIONS=autodig\n"
		@"#OPTIONS=autopickup,pickup_types:$?!/=\"+\n"
		@"#OPTIONS=number_pad:1\n"
		@"#OPTIONS=paranoid_confirmation:pray wand-break\n"
		@"#OPTIONS=sortloot:full\n"
		@"#OPTIONS=fruit:slime mold\n";
}

// not atomic: in the sandbox, an atomic save to the container's Data folder fails with a permission error
BOOL NhCreateOptionsFile(NSString * path, NSError ** error)
{
	if ( [[NSFileManager defaultManager] fileExistsAtPath:path] )
		return YES;
	return [NhOptionsFileTemplate() writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:error];
}
