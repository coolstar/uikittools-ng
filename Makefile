CC = xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=11.0
LDID = ldid

all: cfversion gssc ldrestart sbdidlaunch sbreload uicache uiduid uiopen

cfversion: cfversion.c ent.plist
	$(CC) cfversion.c -o cfversion -framework CoreFoundation -O3
	strip cfversion
	$(LDID) -Sent.plist cfversion

gssc: gssc.m gssc.plist
	$(CC) gssc.m -o gssc -framework Foundation -lMobileGestalt -O3
	strip gssc
	$(LDID) -Sgssc.plist gssc

ldrestart: ldrestart.c ent.plist
	$(CC) ldrestart.c -o ldrestart -I. -O3
	strip ldrestart
	$(LDID) -Sent.plist ldrestart

sbdidlaunch: sbdidlaunch.c ent.plist
	$(CC) sbdidlaunch.c -o sbdidlaunch -framework CoreFoundation -O3
	strip sbdidlaunch
	$(LDID) -Sent.plist sbdidlaunch

sbreload: sbreload.m sbreload-launchd.c sbreload.plist
	$(CC) sbreload.m sbreload-launchd.c -o sbreload -framework Foundation -fobjc-arc -I. -O3
	strip sbreload
	$(LDID) -Ssbreload.plist sbreload

uicache: uicache.m uicache.plist
	$(CC) uicache.m -o uicache -framework Foundation -framework MobileCoreServices -fobjc-arc -O3
	strip uicache
	$(LDID) -Suicache.plist uicache

uiduid: uiduid.m ent.plist
	$(CC) uiduid.m -o uiduid -framework Foundation -lMobileGestalt -fobjc-arc -O3
	strip uiduid
	$(LDID) -Sent.plist uiduid

uiopen: uiopen.m ent.plist
	$(CC) uiopen.m -o uiopen -framework Foundation -framework MobileCoreServices -O3
	strip uiopen
	$(LDID) -Suiopen.plist uiopen

clean:
	rm cfversion sbdidlaunch sbreload uicache uiduid uiopen