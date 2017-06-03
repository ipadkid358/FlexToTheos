## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

TODOs: 
 - Option to name "Sandbox" directory
 - Support for Swift apps
 - Option to only create Tweak.xm 
 - Option to force `dylib`/`plist`/`bundleID`/`name` names

Compile: `make; cp .theos/obj/debug/ftt .`

My "Control B" file: 

```bash
test -f ftt && rm ftt 
make
test -f .theos/obj/debug/ftt && mv .theos/obj/debug/ftt .
rm -r .theos
rm -r obj
test -f ftt && ./ftt 
```
