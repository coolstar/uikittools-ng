CC = xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=11.0
LDID = ldid

all: cfversion sbdidlaunch sbreload uicache uiduid uiopen

cfversion: cfversion.c ent.plist
	$(CC) cfversion.c -o cfversion -framework CoreFoundation
	$(LDID) -Sent.plist cfversion

ldrestart: ldrestart.c ent.plist
	$(CC) ldrestart.c -o ldrestart -I.
	$(LDID) -Sent.plist ldrestart

sbdidlaunch: sbdidlaunch.c ent.plist
	$(CC) sbdidlaunch.c -o sbdidlaunch -framework CoreFoundation
	$(LDID) -Sent.plist sbdidlaunch

sbreload: sbreload.m sbreload.plist
	$(CC) sbreload.m -o sbreload -framework Foundation -fobjc-arc
	$(LDID) -Ssbreload.plist sbreload

uicache: uicache.m uicache.plist
	$(CC) uicache.m -o uicache -framework Foundation -framework MobileCoreServices -fobjc-arc
	$(LDID) -Suicache.plist uicache

uiduid: uiduid.m ent.plist
	$(CC) uiduid.m -o uiduid -framework Foundation -lMobileGestalt -fobjc-arc
	$(LDID) -Sent.plist uiduid

uiopen: uiopen.c ent.plist
	$(CC) uiopen.c -o uiopen -framework CoreFoundation
	$(LDID) -Suiopen.plist uiopen

clean:
	rm cfversion sbdidlaunch sbreload uicache uiduid uiopen