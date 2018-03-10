## FlexToTheos 

Enter a number and get a Theos project. Fairly straight forward CLI

Binaries are available in the [Release](https://github.com/ipadkid358/FlexToTheos/releases) tab, my [Cydia Repo](https://ipadkid.cf/) has Debian packages for installing easily on iOS devices.

```
Usage: ftt [OPTIONS]
 Naming:
   -f    Set name of folder created for project (default is Sandbox)
   -n    Override the tweak name
   -v    Set version (default is  0.0.1)
 Output:
   -d    Only print available local patches, don't do anything (cannot be used with any other options)
   -t    Only print Tweak.xm to console
   -s    Enable smart comments
   -o    Disable output, except errors
   -b    Disable colors in output
 Source:
   -p    Directly plug in number
   -c    Get patches directly from the cloud. Downloads use your Flex downloads.
          Free accounts still have limits. Patch IDs are the last digits in share links
   -r    Get remote patch from 3rd party (generally used to fetch from Sinfool repo)
```

Examples:

`ftt -f MyFolder -n tweak -v 1.0`

`ftt -tsp2`

`ftt -b -c 34224`

`ftt -tsr "https://ipadkid.cf/sinfool/Sandbox/HideUnlockScreenChevron71x/Flex.plist"`
