## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

### Compile:
```bash
git clone https://github.com/ipadkid358/FlexToTheos.git
cd FlexToTheos
make
mv .theos/obj/ftt .
```

[Direct binary download](http://ipadkid.cf/scripts/ftt) (may not be latest from source) 

```
Usage: ./ftt [OPTIONS]
 Options:
   -f    Set name of folder created for project (default is Sandbox)
   -n    Override the tweak name
   -v    Set version (default is  0.0.1)
   -p    Directly plug in number
   -c    Get patches directly from the cloud. Downloads use your Flex downloads.
           Free accounts still have limits. Patch IDs are the last digits in share links
   -r    Get remote patch from 3rd party (generally used to fetch from Sinfool repo)
   -d    Only print available local patches, don't do anything (cannot be used with any other options)
   -t    Only print Tweak.xm to console
   -s    Enable smart comments
   -o    Disable output, except errors
   -b    Disable colors in output
```

Examples:
`./ftt -f MyFolder -n tweak -v 1.0` 

`./ftt -tsp2`

`./ftt -b -c 34224`
