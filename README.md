# flashlmdd_rec_flash_win
## Choose your language
English | [`中文简体`](./README-zh-CN.md)
## brief
Script code for flashing Windows dual-system on LG V50, allowing customization of disk space for Android and Windows.  

Other device repositories:  
- [flashlmdd(lgv50)](https://github.com/heyManNice/flashlmdd_rec_flash_win)  
- [mh2lm5g(lgv50s)](https://github.com/heyManNice/mh2lm5g_rec_flash_win)  
  
To reduce testing costs, the script should be device-specific. For new devices, please create a new Fork.  

## Process Diagram
![过程图片](./pic/process.jpg)

## How to Flash
This script is currently in the testing phase.  
If you are worried about damaging your LG V50, do not flash this package yet. Flashing may fail unexpectedly, and we are not responsible for bricking your device.  
Please ensure you have the ability to unbrick your device before flashing this package.
### Preparation
- Hardware: LG V50 phone, OTG cable, USB drive with at least 8GB capacity
- Software: flashlmdd_rec_flash_win compressed package
- Phone status: Able to enter third-party recovery
### Steps
- Format USB Drive (SD Card): Format the USB drive (or SD card) to exFAT. If it is already in this format, you can skip this step.
- Copy Flash Package: Extract the flashlmdd_rec_flash_win folder from the compressed package and place it in the root directory of the USB drive.
- Configure Flash Package: Open the flashlmdd_rec_flash_win folder and find package.info. Open it with a text editor.
              Here, you can set whether to partition and the partition sizes for Android and Windows.
              If this is the first time installing Windows on your phone, the partition function must be enabled.
- Install TWRP (Optional): The recommended recovery is v50-twrp-installer-v3.6.0-flashlmdd_ab-by_youngguo (included in the compressed package). It was tested during development and has good compatibility.
- Connect USB Drive (SD Card): In TWRP, insert the USB drive (SD card) into the phone and use the mount function to mount the external USB drive.
- Install Windows: Locate /usb-otg/flashlmdd_rec_flash_win/install.zip and flash it like a regular ROM.

## For Developers
The structure of the flash package is as follows:  
flashlmdd_rec_flash_win  
&emsp;&emsp;backups //Directory for partition backups during flashing  
&emsp;&emsp;sources //Windows resource folder   
&emsp;&emsp;&emsp;&emsp;install.wim //Windows resource file  
&emsp;&emsp;&emsp;&emsp;uefi.img  //UEFI file  
&emsp;&emsp;install.zip  //Flash script file  
&emsp;&emsp;package.info //Flash package information and configuration file  

By replacing install.wim, you can install any version of Windows.

Use`.\build.bat release` to generate the install.zip file in ./package_example.  
Use`.\build.bat dev` to generate the test.zip file in ./build and push it to the phone’s /tmp via adb.  

## Related Resources
Binary Programs:  
[bash](https://www.gnu.org/software/bash/bash.html) 
[busybox](https://github.com/meefik/busybox)
[toolbox](/system/bin)
[dos2unix](https://github.com/TizenTeam/dos2unix)
[parted](https://github.com/bcl/parted)
[wimlib-imagex](https://wimlib.net/)
[mkntfs](https://www.tuxera.com/company/open-source/)
[ntfsfix](https://github.com/tuxera/ntfs-3g)
[bcdboot](https://github.com/BigfootACA/bcdboot)
[mkfs.fat](https://github.com/dosfstools/dosfstools)
[7z](https://www.7-zip.org/)
[adb](https://source.android.google.cn/docs/setup/build/adb?hl=zh-cn)

Reference Tutorials:
[woa-flashlmdd](https://github.com/n00b69/woa-flashlmdd/tree/main)
[windows-flashable-script](https://github.com/edk2-porting/windows-flashable-script)

WOA Related Resources:
[msmnilePkg](https://github.com/woa-msmnile/msmnilePkg)
[msmnile-Drivers](https://github.com/woa-msmnile/msmnile-Drivers)

System Images:
- [Luo]Windows 10 Pro Arm64 21390.2050.wim  

twrp：
- v50-twrp-installer-v3.6.0-flashlmdd_ab-by_youngguo220102.zip