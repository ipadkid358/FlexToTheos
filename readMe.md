## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

TODOs: 
 - Support for Swift methods
 - Option to only create Tweak.xm (and copy to clipboard?)

Compile: `make; cp .theos/obj/debug/ftt .`

```
Usage ./ftt [OPTIONS]:
    Options: 
		-f  Set name of folder created for project (default is "Sandbox")
		-n  Override the tweak name
		-v  Set version (default is  %s)
		-p  Directly plug in number (usually for consecutive dumps)
		-d  Only print available patches, don't do anything (cannot be used with any other options)
```


My "Control B" file: 

```bash
test -f ftt && rm ftt 
make
test -f .theos/obj/debug/ftt && mv .theos/obj/debug/ftt .
rm -r .theos
rm -r obj
test -f ftt && ./ftt 
```
