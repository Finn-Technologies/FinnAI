; Inno Setup Script for FinnAI Windows Desktop
; Combines Flutter desktop runner, native llama.cpp runtime, plugins, and assets
; into a single standalone modern Windows installer.

#define MyAppName "FinnAI"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "Finn Technologies"
#define MyAppURL "https://github.com/Finn-Technologies/FinnAI"
#define MyAppExeName "finn_ai.exe"
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\build\windows\installer"
#endif

[Setup]
; Unique application GUID
AppId={{93B8A5B2-793E-4395-88AA-DFE138DEB097}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Dual-mode: installs to %LOCALAPPDATA%\Programs\FinnAI without elevation,
; or to Program Files if run elevated or when selected in the setup dialog.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline

OutputDir={#OutputDir}
OutputBaseFilename=FinnAI-Setup-{#MyAppVersion}-x64
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Maximum LZMA2 solid compression
Compression=lzma2/ultra64
SolidCompression=yes

; Modern wizard appearance and 64-bit native configuration
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
