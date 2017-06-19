## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

TODOs: 
 - Support for Swift classes 

Compile: ```bash
git clone https://github.com/ipadkid358/FlexToTheos.git
cd FlexToTheos
make
mv .theos/obj/debug/ftt .
```

[Direct binary download](https://ipadkid358.github.io/scripts/ftt) (may not be latest from source) 

```
Usage: ./ftt [OPTIONS]
    Options: 
	-f	Set name of folder created for project (default is "Sandbox")
	-n	Override the tweak name
	-v	Set version (default is  0.0.1)
	-p	Directly plug in number (usually for consecutive dumps)
	-d	Only print available patches, don't do anything (cannot be used with any other options)
	-t	Only print Tweak.xm to console (can only be used with -p)
	-s	Enable smart comments (beta option)
```
ex. `./ftt -f MyFolder -n tweak -v 1.0` 

ex. `./ftt -tsp2`

My "Command-B" file: 

(I have a file called `b` with the contents below, and just type `./b` when I'm in the project for quick run and testing)

```bash
test -f ftt && rm ftt 
make
test -f .theos/obj/debug/ftt && mv .theos/obj/debug/ftt .
rm -r .theos
rm -r obj
test -f ftt && ./ftt
```
