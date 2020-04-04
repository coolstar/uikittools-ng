//Huge thanks to Morpheus for this

#include <xpc/xpc.h>

extern int xpc_pipe_routine (xpc_object_t xpc_pipe, xpc_object_t inDict, xpc_object_t *out);
extern char *xpc_strerror (int);

#define HANDLE_SYSTEM 0

// Some of the routine #s launchd recognizes. There are quite a few subsystems

#define ROUTINE_START		0x32d	// 813
#define ROUTINE_STOP		0x32e	// 814
#define ROUTINE_LIST		0x32f	// 815

// XPC sets up global variables using os_alloc_once. By reverse engineering
// you can determine the values. The only one we actually need is the fourth
// one, which is used as an argument to xpc_pipe_routine

struct xpc_global_data {
	uint64_t	a;
	uint64_t	xpc_flags;
	mach_port_t	task_bootstrap_port;  /* 0x10 */
#ifndef _64
	uint32_t	padding;
#endif
	xpc_object_t	xpc_bootstrap_pipe;   /* 0x18 */
	// and there's more, but you'll have to wait for MOXiI 2 for those...
	// ...
};

// os_alloc_once_table:
//
// Ripped this from XNU's libsystem
#define OS_ALLOC_ONCE_KEY_MAX	100

struct _os_alloc_once_s {
	long once;
	void *ptr;
};

extern struct _os_alloc_once_s _os_alloc_once_table[];

extern pid_t springboardPID;
extern pid_t backboarddPID;

int stopService(const char *ServiceName)
{
	xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64 (dict, "subsystem", 3); // subsystem (3)
	xpc_dictionary_set_uint64 (dict, "handle", HANDLE_SYSTEM);
	xpc_dictionary_set_uint64(dict, "routine", ROUTINE_STOP);
	xpc_dictionary_set_uint64 (dict, "type", 1);
	xpc_dictionary_set_string (dict, "name", ServiceName);

	xpc_object_t	*outDict = NULL;

	struct xpc_global_data  *xpc_gd  = (struct xpc_global_data *)  _os_alloc_once_table[1].ptr;

	int rc = xpc_pipe_routine (xpc_gd->xpc_bootstrap_pipe, dict, &outDict);
	if (rc == 0) {
		rc = xpc_dictionary_get_int64 (outDict, "error");
		if (rc) {
			fprintf(stderr, "Error stopping service:  %d - %s\n", rc, xpc_strerror(rc));
			return (rc);
		}
	}
	return rc;
}

int updatePIDs(){
	xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(dict, "subsystem", 3); // subsystem (3)
	xpc_dictionary_set_uint64(dict, "handle", HANDLE_SYSTEM);
	xpc_dictionary_set_uint64(dict, "routine", ROUTINE_LIST);
	xpc_dictionary_set_uint64(dict, "type", 1); // set to 1
	xpc_dictionary_set_bool(dict, "legacy", 1); // mandatory

	xpc_object_t	*outDict = NULL;

	struct xpc_global_data  *xpc_gd  = (struct xpc_global_data *)  _os_alloc_once_table[1].ptr;

	int rc = xpc_pipe_routine (xpc_gd->xpc_bootstrap_pipe, dict, &outDict);
	if (rc == 0) {
		int err = xpc_dictionary_get_int64 (outDict, "error");
		if (!err){
			// We actually got a reply!
			xpc_object_t svcs = xpc_dictionary_get_value(outDict, "services");
			if (!svcs)
			{
				fprintf(stderr,"Error: no services returned for list\n");
				return 1;
			}

			xpc_type_t	svcsType = xpc_get_type(svcs);
			if (svcsType != XPC_TYPE_DICTIONARY)
			{
				fprintf(stderr,"Error: services returned for list aren't a dictionary!\n");
				return 2;
			}

			xpc_dictionary_apply(svcs, ^bool (const char *label, xpc_object_t svc) 
			{
				int64_t pid = xpc_dictionary_get_int64(svc, "pid");
				if (pid != 0){
					if (strcmp(label, "com.apple.SpringBoard") == 0){
						springboardPID = pid;
					}
					if (strcmp(label, "com.apple.backboardd") == 0){
						backboarddPID = pid;
					}
				}
				return 1;
			});
		} else {
			fprintf(stderr, "Error:  %d - %s\n", err, xpc_strerror(err));
		}
	} else {
		fprintf(stderr, "Unable to get launchd: %d\n", rc);
	}
	return rc;
}
