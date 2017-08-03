## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

TODOs: 
 - Support for Swift classes 

Compile:
```bash
git clone https://github.com/ipadkid358/FlexToTheos.git
cd FlexToTheos
make
mv .theos/obj/debug/ftt .
```

[Direct binary download](https://ipadkid358.github.io/scripts/ftt) (may not be latest from source) 

```
Usage: ./ftt [OPTIONS]
   Options:
      -f    Set name of folder created for project (default is Sandbox)
      -n    Override the tweak name
      -v    Set version (default is  0.0.1)
      -p    Directly plug in number
      -c    Get patches directly from the cloud. Downloads use your Flex downloads.
              Free accounts still have limits. Patch IDs are the last digits in share links
      -d    Only print available local patches, don't do anything (cannot be used with any other options)
      -t    Only print Tweak.xm to console
      -s    Enable smart comments
      -o    Disable output, except errors
      -b    Disable colors in output
```
ex. `./ftt -f MyFolder -n tweak -v 1.0` 

ex. `./ftt -tsp2`

ex. `./ftt -b -c 38201`
