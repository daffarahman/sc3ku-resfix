# SimCity 3K Unlimited Native Resolution Fix
SC3KU Native Resolution and Menu Fix Patch on newer OS (Windows 10/11)  

## About
This configuration fix addresses the missing menu background and dialogs seen with DDrawCompat and some Intel Direct3D 9 drivers at high resolutions. It uses the Windows D3D9On12 rendering path and enables native monitor resolutions, including 1920x1200. The original 800x600 menu artwork remains centered with black margins. City rendering uses the selected game resolution.  

## Requirements
- Windows 10 or newer and a DirectX 12 capable GPU.
- SimCity 3000 Unlimited with an existing widescreen-unlocked SC3U.exe.
- DDrawCompat v0.5.3 or newer installed as Apps\ddraw.dll.
  Official downloads: https://github.com/narzoul/DDrawCompat/releases
  Widescreen unlock: https://github.com/tetration/Simcity3000-HD-patch

## Install
1. Close the game.
2. Copy Apply-SC3U-Resolution-Fix.bat into the game folder (containing Apps),
   or directly into Apps beside SC3U.exe.
3. Double-click the BAT. If Windows denies write access, run as administrator.
4. Launch the game. In Preferences > Screen Resolution, choose your monitor's
   resolution, for example 1920x1200. This installer does not force a resolution
   into the game's binary SC3.cfg file.
   
### You can also run it from another folder:
`Apply-SC3U-Resolution-Fix.bat "C:\Games\SimCity 3000 Unlimited"`  

## Patch
The installer sets these three options in Apps\DDrawCompat-SC3U.ini:
```
SupportedResolutions = native, [common modes and your existing custom modes]
ForceD3D9On12 = on
FullscreenMode = borderless
```  

If Apps\DDrawCompatOverlay-SC3U.ini exists, it updates the same options there because overlay settings override process settings. It preserves unrelated configuration options, existing custom resolution entries, and the first original backups. Running it again does not duplicate settings.  

No game executables, DLLs, registry entries, SC3.cfg preferences, or city saves are changed. The package does not include or download game files or wrappers.  

## Uninstalling
Run from a command prompt:
`Apply-SC3U-Resolution-Fix.bat /undo "C:\Games\SimCity 3000 Unlimited"`  

If the BAT is already in the game folder or Apps, the folder argument is optional. Undo restores only the three affected settings to their values from the first installation. Later changes to other settings are retained. A configuration file created by this installer is removed only if undo leaves it empty. Original files remain in Apps\SC3U-Resolution-Fix-Backup for manual recovery. Keep that backup folder until you no longer need to undo this installation.  

## Testing
The rendering fix was checked with DDrawCompat v0.5.3 on Windows and Intel Iris Xe graphics: menus at 1920x1080 and 1920x1200, Preferences, and a starter city at 1920x1200. Other graphics cards and long play sessions were not tested. Use resolutions whose width and height are both divisible by 8; other modes can be unstable with the widescreen unlock. D3D9On12 is an experimental DDrawCompat option and may behave differently on other machines. If DDrawCompat's in-game overlay later changes these settings, reapply the BAT.  

## Documentation
```
https://github.com/narzoul/DDrawCompat/wiki/Configuration#forced3d9on12
https://github.com/narzoul/DDrawCompat/wiki/Configuration#supportedresolutions
```  
