# ImageMagick Watermarker
A Bash script for watermarking images using ImageMagick, adjusted for using in Termux on Android. 

## Dependencies
* ImageMagick v7
* exiftool (for extracting location and time info)
* libxml2-utils

## Usage
The script use Amap api for converting coordinate (WGS-84 to GCJ-02) and requesting address, you have to request API Key to make it functioning normally.

After requesting API Key, simply paste into the value of `amapapi` in the script and save.

Make sure Termux has granted full storage access permission before processing. You can use `termux-setup-storage` to achieve this.

Change directory to where your photos save (usually `/storage/emulated/0`), then execute:

`~/watermark.sh 6` (6 means photos count you've recently taken)

The processed photo will save in `WatermarkProcess` folder of your Internal Storage.

If your phone has Superuser, you can use the `am broadcast` function to make processed photos found by other programs.

(The script can't broadcast file change without superuser rights or adb)
