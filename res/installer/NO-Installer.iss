; Instalador EXE do NÓ.
; O payload é preparado pelo CI (NO.exe + DLLs + data) e passado em /DPayloadDir.
#define MyAppName "NÓ - suporte remoto local"
#ifndef MyAppVersion
  #define MyAppVersion "1.5.1"
#endif
#ifndef MyAppBuild
  #define MyAppBuild "68"
#endif
#define MyAppPublisher "Purslane Tech Pte. Ltd."
#define MyAppExeName "NO.exe"
#ifndef PayloadDir
  #define PayloadDir "payload"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\installer-output"
#endif

[Setup]
AppId={{B6E0F3D4-2A7C-4F1E-9A3B-8C5D7E2F1A90}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\NO
DefaultGroupName=NÓ
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableWelcomePage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
PrivilegesRequired=admin
OutputDir={#OutputDir}
OutputBaseFilename=Instalar-NO
SetupIconFile=..\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Instalador do NÓ
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}.{#MyAppBuild}
VersionInfoOriginalFileName=Instalar-NO.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

; Remove resquícios do instalador PowerShell anterior, que criava atalhos e
; scripts auxiliares com nomes diferentes.
[InstallDelete]
Type: files; Name: "{commondesktop}\NO.lnk"
Type: files; Name: "{commonprograms}\NO.lnk"
Type: filesandordirs; Name: "{commonappdata}\NO"

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\NO"; Flags: deletekey
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\NO"; Flags: deletekey 64

[Files]
Source: "{#PayloadDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NÓ"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\NÓ"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Flags: nowait runasoriginaluser skipifsilent

[UninstallRun]
Filename: "{sys}\sc.exe"; Parameters: "stop NO"; Flags: runhidden waituntilterminated; RunOnceId: "StopNOService"
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM NO.exe"; Flags: runhidden; RunOnceId: "StopNOProcess"
Filename: "{app}\{#MyAppExeName}"; Parameters: "--uninstall-service"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveNOService"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""NO 21118 TCP"""; Flags: runhidden; RunOnceId: "RemoveNOFirewallTCP"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""NO 21118 UDP"""; Flags: runhidden; RunOnceId: "RemoveNOFirewallUDP"

[Code]
var
  InstallLog: string;

procedure AddLog(const S: string);
begin
  Log(S);
  if InstallLog <> '' then
    SaveStringToFile(InstallLog, GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + ' ' + S + #13#10, True);
end;

function RunHidden(const FileName, Params, WorkingDir: string): Integer;
var
  ResultCode: Integer;
begin
  Result := -1;
  if Exec(FileName, Params, WorkingDir, SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Result := ResultCode
  else
    AddLog('Falha ao executar: ' + FileName + ' ' + Params);
end;

function InitializeSetup(): Boolean;
begin
  InstallLog := GetEnv('TEMP');
  if InstallLog = '' then
    InstallLog := ExpandConstant('{tmp}');
  InstallLog := InstallLog + '\NO-install.log';
  AddLog('Iniciando instalador do NÓ.');
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  R: Integer;
  Exe: string;
begin
  if CurStep = ssInstall then
  begin
    AddLog('Parando instância e serviço existentes.');
    RunHidden(ExpandConstant('{sys}\sc.exe'), 'stop NO', '');
    RunHidden(ExpandConstant('{sys}\ping.exe'), '-n 2 127.0.0.1', '');
    RunHidden(ExpandConstant('{sys}\taskkill.exe'), '/F /IM NO.exe', '');
    RunHidden(ExpandConstant('{sys}\ping.exe'), '-n 2 127.0.0.1', '');
  end
  else if CurStep = ssPostInstall then
  begin
    AddLog('Criando regras de firewall.');
    R := RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall delete rule name="NO 21118 TCP"', '');
    R := RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall add rule name="NO 21118 TCP" dir=in action=allow protocol=TCP localport=21118 profile=any', '');
    if R <> 0 then
      AddLog('Aviso: firewall TCP retornou ' + IntToStr(R));
    R := RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall delete rule name="NO 21118 UDP"', '');
    R := RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall add rule name="NO 21118 UDP" dir=in action=allow protocol=UDP localport=21118 profile=any', '');
    if R <> 0 then
      AddLog('Aviso: firewall UDP retornou ' + IntToStr(R));

    Exe := ExpandConstant('{app}\NO.exe');
    AddLog('Instalando serviço do NÓ.');
    R := RunHidden(Exe, '--install-service', ExpandConstant('{app}'));
    if R <> 0 then
    begin
      AddLog('Falha ao instalar serviço. Código: ' + IntToStr(R));
      MsgBox('Não foi possível instalar o serviço do NÓ (código ' + IntToStr(R) + ').' + #13#10 + #13#10 + 'Log: ' + InstallLog, mbError, MB_OK);
      Abort;
    end;

    R := RunHidden(ExpandConstant('{sys}\sc.exe'), 'start NO', '');
    if R <> 0 then
    begin
      R := RunHidden(ExpandConstant('{sys}\sc.exe'), 'query NO', '');
      if R <> 0 then
      begin
        AddLog('Serviço não encontrado após instalação.');
        MsgBox('O serviço do NÓ não foi encontrado após a instalação.' + #13#10 + #13#10 + 'Log: ' + InstallLog, mbError, MB_OK);
        Abort;
      end;
    end;
    AddLog('Instalação concluída.');
  end;
end;
