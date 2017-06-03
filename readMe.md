## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

TODOs: 
 - Support for Swift methods
 - Option to only create Tweak.xm (and copy to clipboard?)

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
