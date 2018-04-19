## FlexToTheos 

Convert Flex patches into Theos projects. Fairly straight forward CLI

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
   -l    Generate plain Obj-C instead of logos
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


### TODOs

- Fix `codeFromFlexPatch` to reuse code

- Potentially add macOS support for remote patches (supported options would be `-fnvdtlsor`)


### Background

I started working on this project in late April, 2017, in an effort to create the [Sinfool](https://ipadkid.cf/sinfool/) repo. Some [early archives](https://ipadkid.cf/ftt/) are still available. This project is a reminder to me, and I hope others, that anyone can get into (software) development. I started on my jailbroken iPhone, editing the Bash scripts with a plain text editor. After some developers saw what I was doing, they recommended I use a "real" language. I had briefly used Objective-C in the past, and with the help of developers in the Jailbreak Discord, I finished the first version without ever touching a computer other than my phone.

There are two important points I hope this shows

1. Anyone can get into development. You do not need a super powerful computer, or even a laptop

2. Jailbreaking allows young developers to more easily get into development

Adding onto the last point, Swift Playgrounds for iPad has opened up that door a little bit, but as one developer put it, "[Swift Playgrounds] teaches *about* code, not *how* to code".
