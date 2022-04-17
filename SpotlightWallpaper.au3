#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=main.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductVersion=1.0.0.0
#AutoIt3Wrapper_Res_Description=Use spotlight lock screen images as wallpaper

#include <APIFilesConstants.au3>
#include <Array.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIError.au3>
#include <WinAPIFiles.au3>
#include <WinAPIMem.au3>
#include <MsgBoxConstants.au3>
#include <GUIConstantsEx.au3>
#include <WinAPIFiles.au3>
#include <GUIConstants.au3>
#include <File.au3>
#include <GDIPlus.au3>
#include <GuiButton.au3>
#include <TrayConstants.au3>

#include 'lib\authread.au3'
#include 'lib\GUIHyperLink.au3'

OnAutoItExitRegister("ExitApp")
Opt("TrayMenuMode", 3)

Global Const $sConfigPath = @AppDataDir & '\SpotlightWallpaper\config.ini'
Global Const $sDEST_URL = @UserProfileDir & '\Pictures\wallpapers\landscape\'
Global Const $sBASE_URL = @LocalAppDataDir & '\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets\'
Global $nIndex = IniRead($sConfigPath, "Settings", "ImageIndex", "1")

Global $aFileList
Global $idPic
Global $idIndicator
Global $hThread

_AuThread_Startup()
Main()

Func Main()
	Local Const $sREPO_URL = 'https://github.com/chunqiuyiyu/spotlight-wallpaper'
	Local Const $sLINK_PATH = @StartupDir & '\SpotlightWallpaper.lnk'

	$hGUI = GUICreate("Spotlight Wallpaper", 800, 600)

	$sRunAtStartup = IniRead($sConfigPath, "Settings", "RunAtStartup", "0")
	$sAutoSet = IniRead($sConfigPath, "Settings", "AutoSet", "0")
	$sTimer = IniRead($sConfigPath, "Settings", "Timer", "8")

	$idRunStartup = GUICtrlCreateCheckbox('Run at startup', 20, 10)
	$idAutoset = GUICtrlCreateCheckbox('Auto set every', 140, 10)
	$idTimer = GUICtrlCreateInput($sTimer, 250, 12, 30, 20, $ES_NUMBER)
	GUICtrlCreateLabel('hrs', 290, 15)

	_GUICtrlHyperLink_Create("About", 750, 15, 30, 20, 0x0000FF, 0x0000FF, _
			 -1, $sREPO_URL, 'Visit GitHub repository', $hGUI)

	GUICtrlCreateGroup("Preview", 20, 45, 760, 465)

	CopyImages($sBASE_URL)
	$aFileList = ReadDir($sDEST_URL)
	If $nIndex > $aFileList[0] Then
		$nIndex = 1
	EndIf
	$idPic = GUICtrlCreatePic($sDEST_URL & $aFileList[$nIndex], 30, 65, 740, 435)

	; Controllers
	$idBtnPrev = GUICtrlCreateButton('Prev', 20, 530, 100, 30)
	$idBtnNext = GUICtrlCreateButton('Next', 140, 530, 100, 30)
	$idBtnRandom = GUICtrlCreateButton('Random', 260, 530, 100, 30)
	$idIndicator = GUICtrlCreateLabel($nIndex & '/' & $aFileList[0], 380, 540)
	$idBtnSet = GUICtrlCreateButton('Set', 680, 530, 100, 30)

	$label = GUICtrlCreateLabel("   Ready", 0, 580, 800, 20, $SS_LEFT + $SS_SUNKEN)

	$idRestore = TrayCreateItem("Restore")
	$idAbout = TrayCreateItem("About")

	$idExit = TrayCreateItem("Exit")
	TraySetState($TRAY_ICONSTATE_SHOW)

	If $sRunAtStartup == '1' Then
		_GUICtrlButton_SetCheck($idRunStartup, $BST_CHECKED)

		FileCreateShortcut(@WorkingDir & '\' & @ScriptName, $sLINK_PATH)
	EndIf

	If $sAutoSet == '1' Then
		_GUICtrlButton_SetCheck($idAutoset, $BST_CHECKED)

		$nTimer = GUICtrlRead($idTimer)
		AdlibRegister("TimeUp", $nTimer * 60 * 60 * 1000)
	EndIf

	GUISetState(@SW_SHOW)
	GUICtrlSetState($idBtnSet, $GUI_FOCUS)

	$hThread = _AuThread_StartThread("Watch")
	Opt("TrayIconHide", 0)

	While 1
		; Tray icon message
		Switch TrayGetMsg()
			Case $idRestore
				GUISetState(@SW_SHOW)
				GUISetState(@SW_RESTORE)

			Case $idAbout
				ShellExecute($sREPO_URL)

			Case $idExit
				ExitApp()

		EndSwitch

		; GUI message
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				ExitApp()

			Case $GUI_EVENT_MINIMIZE
				GUISetState(@SW_MINIMIZE)
				GUISetState(@SW_HIDE)

			Case $idBtnNext
				SetNextWallpaper()

			Case $idBtnPrev
				$nIndex -= 1
				If $nIndex < 1 Then
					$nIndex = $aFileList[0]
				EndIf
				SetImage()

			Case $idBtnRandom
				$nIndex = Random(1, $aFileList[0], 1)
				SetImage()

			Case $idRunStartup
				Write_Config($sConfigPath, 'RunAtStartup', _IsChecked($idRunStartup) ? '1' : '0')

				If _IsChecked($idRunStartup) Then
					FileCreateShortcut(@WorkingDir & '\' & @ScriptName, $sLINK_PATH)
				Else
					FileDelete($sLINK_PATH)
				EndIf

			Case $idAutoset
				Write_Config($sConfigPath, 'AutoSet', _IsChecked($idAutoset) ? '1' : '0')

				If _IsChecked($idAutoset) Then
					$nTimer = GUICtrlRead($idTimer)
					AdlibRegister("TimeUp", $nTimer * 60 * 60 * 1000)
				Else
					AdlibUnRegister("TimeUp")
				EndIf

			Case $idTimer
				$nTimer = GUICtrlRead($idTimer)
				If $nTimer = 0 Then
					MsgBox($MB_SYSTEMMODAL, "Warning", "You should enter no-zero number.")
				Else
					Write_Config($sConfigPath, 'Timer', $nTimer)
				EndIf

			Case $idBtnSet
				_SetDesktopWallpaper()

		EndSwitch

		; Thread message
		$sMsg = _AuThread_GetMessage()
		If $sMsg Then
			CopyImages($sBASE_URL)
			Sleep(1000)
			$aFileList = ReadDir($sDEST_URL)
			GUICtrlSetData($idIndicator, $nIndex & '/' & $aFileList[0])
			GUICtrlSetData($label, '   Last updated on ' & $sMsg)
		EndIf
	WEnd

	GUIDelete()
EndFunc   ;==>Main

Func TimeUp()
	SetNextWallpaper()
	_SetDesktopWallpaper()
EndFunc   ;==>TimeUp

Func SetNextWallpaper()
	$nIndex += 1
	If $nIndex > $aFileList[0] Then
		$nIndex = 1
	EndIf
	SetImage()
EndFunc   ;==>SetNextWallpaper

Func Write_Config($sConfigPath, $sKey, $sVal)
	If FileExists($sConfigPath) Then
		IniWrite($sConfigPath, 'Settings', $sKey, $sVal)
	Else
		Local $hFileOpen = FileOpen($sConfigPath, $FO_CREATEPATH + $FO_APPEND)
		If $hFileOpen = -1 Then
			MsgBox($MB_SYSTEMMODAL, "Error", "An error occurred whilst writing the configure file.")
			Return False
		EndIf
		; Close the handle returned by FileOpen.
		FileClose($hFileOpen)
		IniWrite($sConfigPath, 'Settings', $sKey, $sVal)
	EndIf
EndFunc   ;==>Write_Config

Func _IsChecked($idControlID)
	Return BitAND(GUICtrlRead($idControlID), $GUI_CHECKED) = $GUI_CHECKED
EndFunc   ;==>_IsChecked


Func CopyImages($sBASE_URL, $aMyFileList = '')
	$aFileList = $aMyFileList
	If $aFileList == '' Then
		$aFileList = ReadDir($sBASE_URL)
	EndIf

	_GDIPlus_Startup()
	For $vElement In $aFileList
		$nIndex = _ArraySearch($aFileList, $vElement)
		$dest = 'landscape\'
		If $nIndex <> 0 Then
			$FileLoad = _GDIPlus_ImageLoadFromFile($sBASE_URL & $aFileList[$nIndex])

			$h = _GDIPlus_ImageGetHeight($FileLoad)
			$w = _GDIPlus_ImageGetWidth($FileLoad)

			_GDIPlus_ImageDispose($FileLoad)

			If $h > $w Then
				$dest = 'portrait\'
			EndIf

			; Just copy images
			If $h <> -1 And $w <> -1 Then
				FileCopy($sBASE_URL & $aFileList[$nIndex], @UserProfileDir & '\Pictures\wallpapers\' & $dest & $aFileList[$nIndex] & '.jpg', $FC_CREATEPATH)
			EndIf

		EndIf
	Next
	_GDIPlus_Shutdown()
EndFunc   ;==>CopyImages

Func SetImage()
	GUICtrlSetImage($idPic, $sDEST_URL & $aFileList[$nIndex])
	GUICtrlSetData($idIndicator, $nIndex & '/' & $aFileList[0])
	Write_Config($sConfigPath, 'ImageIndex', $nIndex)
EndFunc   ;==>SetImage

Func ReadDir($sDir)
	; List all the files and folders in the desktop directory using the default parameters.
	Local $aFileList = _FileListToArray($sDir, "*")

	If @error = 1 Then
		MsgBox($MB_SYSTEMMODAL, "Error", "Path was invalid.")
		Exit
	EndIf
	If @error = 4 Then
		MsgBox($MB_SYSTEMMODAL, "Error", "No file(s) were found.")
		Exit
	EndIf

	Return $aFileList

EndFunc   ;==>ReadDir


Func Watch()
	Local $sMY_BASE_URL = StringTrimRight($sBASE_URL, 1)
	Local $hDirectory = _WinAPI_CreateFileEx($sMY_BASE_URL, $OPEN_EXISTING, $FILE_LIST_DIRECTORY, BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE), $FILE_FLAG_BACKUP_SEMANTICS)
	If @error Then
		_WinAPI_ShowLastError('', 1)
	EndIf

	Local $pBuffer = _WinAPI_CreateBuffer(8388608)
	Local $aData
	While 1
		$aData = _WinAPI_ReadDirectoryChanges($hDirectory, BitOR($FILE_NOTIFY_CHANGE_FILE_NAME, $FILE_NOTIFY_CHANGE_DIR_NAME), $pBuffer, 8388608, 1)
		If Not @error Then
			$t = FileGetTime($sMY_BASE_URL)
			$yyyymd = $t[0] & "/" & $t[1] & "/" & $t[2] & " " & $t[3] & ":" & $t[4] & ":" & $t[5]
			_AuThread_SendMessage(_AuThread_MainThread(), $yyyymd)
		Else
			_WinAPI_ShowLastError('', 1)
		EndIf
	WEnd
EndFunc   ;==>Watch

Func _SetDesktopWallpaper()
	Local $aResult
	Local $iWinIni = 1
	Local $SPI_SETDESKWALLPAPER = 20
	Local $sFile = $sDEST_URL & $aFileList[$nIndex]

	$aResult = DllCall("user32.dll", "int", "SystemParametersInfo", "int", $SPI_SETDESKWALLPAPER, _
			"int", 0, "str", $sFile, "int", $iWinIni)
	Return $aResult[0] <> 0
EndFunc   ;==>_SetDesktopWallpaper

Func ExitApp()
	AdlibUnRegister("TimeUp")
	_AuThread_CloseThread($hThread)
	Exit
EndFunc   ;==>ExitApp
