//
//  cocoa_unix.c
//  NetHackCocoa
//
//  Created by Bryce Cogswell on 1/2/21.
//

/* NetHack may be freely redistributed.  See license for details. */

#include "hack.h"

#include <sys/stat.h>
#include <fcntl.h>

void set_fqn_prefixes(void);

static void
touch_file(const char *dir, const char *name)
{
	char path[1024];

	Snprintf(path, sizeof path, "%s/%s", dir, name);
	close(open(path, O_CREAT | O_WRONLY, 0666));
}

/* Writable files live in ~/nethackdir (inside the sandbox container);
   read-only data stays in the app bundle, which is the cwd. */
void
set_fqn_prefixes(void)
{
	char dirbuf[1024], savedir[1024];
	char *nethackdir = nh_getenv("NETHACKDIR");
	size_t len;
	char *prefix;

	if (!nethackdir)
		nethackdir = nh_getenv("HACKDIR");
	if (!nethackdir) {
		Snprintf(dirbuf, sizeof dirbuf, "%s/nethackdir", getenv("HOME"));
		nethackdir = dirbuf;
	}

	mkdir(nethackdir, 0777);
	touch_file(nethackdir, "perm");
	touch_file(nethackdir, "record");
	touch_file(nethackdir, "logfile");
	touch_file(nethackdir, "xlogfile");
	Snprintf(savedir, sizeof savedir, "%s/save", nethackdir);
	mkdir(savedir, 0777);

	len = strlen(nethackdir);
	prefix = (char *) alloc(len + 2);
	Strcpy(prefix, nethackdir);
	if (prefix[len - 1] != '/') {
		prefix[len] = '/';
		prefix[len + 1] = '\0';
	}
	gf.fqn_prefix[SCOREPREFIX] = prefix;
	gf.fqn_prefix[LEVELPREFIX] = prefix;
	gf.fqn_prefix[SAVEPREFIX] = prefix;
	gf.fqn_prefix[BONESPREFIX] = prefix;
	gf.fqn_prefix[LOCKPREFIX] = prefix;
	gf.fqn_prefix[TROUBLEPREFIX] = prefix;
}
