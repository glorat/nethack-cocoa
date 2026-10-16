#import "PlayerName.h"

// as tty: the name becomes part of the save file's name, and a leading
// digit would run into the uid in front of it
BOOL NhPlayerName(const char * typed, char * name, size_t size)
{
	if ( typed[0] == '\033' )
		return NO;
	size_t n = 0;
	for ( ; typed[n] && n < size - 1; ++n ) {
		char c = typed[n];
		BOOL ok = isalpha((unsigned char)c) || c == '-' || c == '@' || (isdigit((unsigned char)c) && n > 0);
		name[n] = ok ? c : '_';
	}
	name[n] = '\0';
	return n > 0;
}
