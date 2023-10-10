/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCoalface.h"
#import "BXEmulatorPrivate.h"
#import "setup.h"
#import "mapper.h"
#import "cross.h"
#import "shell.h"
#import "ADBFilesystem.h"

#pragma mark - Runloop state functions

/// This is called in place of DOSBox's GFX_Events to allow us to process events when the DOSBox
/// core runloop gives us time.
bool boxer_processEvents()
{
	[[BXEmulator currentEmulator] _processEvents];
    return !shutdown_requested || !boxer_runLoopShouldContinue();
}

/*
 static void UpdateFramePeriod()
 {
     assert(sdl.window);
     SDL_DisplayMode display_mode;
     SDL_GetWindowDisplayMode(sdl.window, &display_mode);
     const int refresh_rate = display_mode.refresh_rate > 0
                                      ? display_mode.refresh_rate
                                      : 60;
     frame_period = std::chrono::nanoseconds(1'000'000'000 / refresh_rate);
 }

 */

//TODO: move to BXEmulator
//! The frame-period holds the current duration for which a single host
//! video-frame is displayed. This is kept up-to-date when the video mode is set.
//! A sane starting value is used, which is based on a 60-Hz monitor.
auto frame_period = std::chrono::nanoseconds(1'000'000'000 / 60);
bool boxer_MaybeProcessEvents()
{
    // Process SDL's event queue at 200 Hz
    constexpr auto ps2_poll_period = std::chrono::nanoseconds(1'000'000'000 / 200);

    // SDL maintainers recommend processing the SDL's event queue before
    // each frame. For now, simply ensure that the PS/2 polling period is
    // quicker than the video frame period. If a time comes when common
    // displays update faster than 200 Hz, then update this code to pick the
    // quicker of the two.
    assert(ps2_poll_period <= frame_period);

    static auto next_process_at = std::chrono::steady_clock::now() + ps2_poll_period;
    const auto checked_at = std::chrono::steady_clock::now();
    if (checked_at < next_process_at)
        return true;

    const bool process_result = boxer_processEvents();

#if defined(REPORT_EVENT_LAG)
    const auto host_lag = std::chrono::steady_clock::now() - checked_at;
    if (host_lag > std::chrono::milliseconds(3)) {
        const std::chrono::duration<double, std::milli> lag_ms = host_lag;
        LOG_MSG("SDL: Processing SDL's event queue took %5.2f ms",
                lag_ms.count());
    }
#endif

    next_process_at = checked_at + ps2_poll_period;
    return process_result;
}

/// Called at the start and end of every iteration of DOSBOX_RunMachine.
void boxer_runLoopWillStartWithContextInfo(void **contextInfo)
{
	[[BXEmulator currentEmulator] _runLoopWillStartWithContextInfo: contextInfo];
}

void boxer_runLoopDidFinishWithContextInfo(void *contextInfo)
{
	[[BXEmulator currentEmulator] _runLoopDidFinishWithContextInfo: contextInfo];
}

/// This is called at the start of DOSBox_NormalLoop, and
/// allows us to short-circuit the current run loop if needed.
bool boxer_runLoopShouldContinue()
{
	return [[BXEmulator currentEmulator] _runLoopShouldContinue];
}

/// Notifies Boxer of changes to title and speed settings
void boxer_handleDOSBoxTitleChange(int32_t newCycles, int newFrameskip, bool newPaused)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didChangeEmulationState];
}


#pragma mark - Rendering functions

void boxer_applyRenderingStrategy()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator videoHandler] applyRenderingStrategy];
}

void boxer_setShader(const ShaderInfo& shader_info, const std::string& shader_source) {
    //TODO: implement!
}

Bitu boxer_prepareForFrameSize(Bitu width, Bitu height, Bitu gfx_flags, double scalex, double scaley, GFX_CallBack_t callback, double pixel_aspect)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	
	NSSize outputSize	= NSMakeSize((CGFloat)width, (CGFloat)height);
	NSSize scale		= NSMakeSize((CGFloat)scalex, (CGFloat)scaley);
	[[emulator videoHandler] prepareForOutputSize: outputSize atScale: scale withCallback: callback];
	
	return GFX_CAN_32;
}

Bitu boxer_idealOutputMode(Bitu flags)
{
	//Originally this tested various bit depths to find the most appropriate mode for the chosen scaler.
	//Because OS X always uses a 32bpp context and Boxer always uses RGBA-capable scalers, we ignore the
	//original function's behaviour altogether and just return something that will keep DOSBox happy.
	return GFX_CAN_32;
}

bool boxer_startFrame(uint8_t * &frameBuffer, int & pitch)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [[emulator videoHandler] startFrameWithBuffer: (void **)&frameBuffer pitch: &pitch];
}

void boxer_finishFrame(const uint16_t *dirtyBlocks)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator videoHandler] finishFrameWithChanges: dirtyBlocks];	
}

uint32_t boxer_getRGBPaletteEntry(uint8_t red, uint8_t green, uint8_t blue)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [[emulator videoHandler] paletteEntryWithRed: red green: green blue: blue];
}


#pragma mark - Shell-related functions

void boxer_shellWillStart(DOS_Shell *shell)
{
	[[BXEmulator currentEmulator] _shellWillStart: shell];
}

void boxer_shellDidFinish(DOS_Shell *shell)
{
	[[BXEmulator currentEmulator] _shellDidFinish: shell];
}

bool boxer_shellShouldContinue(DOS_Shell *shell)
{
	return ![BXEmulator currentEmulator].isCancelled;
}

//Catch shell input and send it to our own shell controller - returns YES if we've handled the command,
//NO if we want to let it go through
//This is called by DOS_Shell::DoCommand in DOSBox's shell/shell_cmds.cpp, to allow us to hook into what
//goes on in the shell
bool boxer_shellShouldRunCommand(DOS_Shell *shell, char* cmd, char* args)
{
	NSString *command			= [NSString stringWithCString: cmd	encoding: BXDirectStringEncoding];
	NSString *argumentString	= [NSString stringWithCString: args	encoding: BXDirectStringEncoding];
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	bool handledInternally = [emulator _handleCommand: command withArgumentString: argumentString];
    return !handledInternally;
}

bool boxer_handleShellCommandInput(DOS_Shell *shell, char *cmd, Bitu *cursorPosition, bool *executeImmediately)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    NSString *inOutCommand = [NSString stringWithCString: cmd encoding: BXDirectStringEncoding];
	
    if ([emulator _handleCommandInput: &inOutCommand
                       cursorPosition: (NSUInteger *)cursorPosition
                       executeCommand: (BOOL *)executeImmediately])
	{
		const char *newcmd = [inOutCommand cStringUsingEncoding: BXDirectStringEncoding];
		if (newcmd)
		{
            strlcpy(cmd, newcmd, CMD_MAXLINE);
            return true;
		}
		else return false;
	}
	return false;
}

bool boxer_executeNextPendingCommandForShell(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _executeNextPendingCommand];
}

bool boxer_hasPendingCommandsForShell(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
	return emulator.commandQueue.count > 0;
}

void boxer_shellWillReadCommandInputFromHandle(DOS_Shell *shell, uint16_t handle)
{
    if (handle == STDIN)
    {
        BXEmulator *emulator = [BXEmulator currentEmulator];
        emulator.waitingForCommandInput = YES;
    }
}
void boxer_shellDidReadCommandInputFromHandle(DOS_Shell *shell, uint16_t handle)
{
    if (handle == STDIN)
    {
        BXEmulator *emulator = [BXEmulator currentEmulator];
        emulator.waitingForCommandInput = NO;
    }
}

void boxer_didReturnToShell(DOS_Shell *shell)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didReturnToShell];
}

void boxer_shellWillStartAutoexec(DOS_Shell *shell)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _willRunStartupCommands];
}

void boxer_shellWillExecuteFileAtDOSPath(DOS_Shell *shell, const char *path, const char *arguments)
{	
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _willExecuteFileAtDOSPath: path withArguments: arguments isBatchFile: NO];
}

void boxer_shellDidExecuteFileAtDOSPath(DOS_Shell *shell, const char *path)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _didExecuteFileAtDOSPath: path];
}

void boxer_shellWillBeginBatchFile(DOS_Shell *shell, const char *path, const char *arguments)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _willExecuteFileAtDOSPath: path withArguments: arguments isBatchFile: YES];
}

void boxer_shellDidEndBatchFile(DOS_Shell *shell, const char *canonicalPath)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _didExecuteFileAtDOSPath: canonicalPath];
}

bool boxer_shellShouldDisplayStartupMessages(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _shouldDisplayStartupMessagesForShell: shell];
}


#pragma mark - Filesystem functions

FILE *boxer_openCaptureFile(const char *typeDescription, const char *fileExtension)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _openFileForCaptureOfType:typeDescription extension: fileExtension];
}

//Whether or not to allow the specified path to be mounted.
//Called by MOUNT::Run in DOSBox's dos/dos_programs.cpp.
bool boxer_shouldMountPath(const char *path)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldMountLocalPath: path];
}

//Whether to include a file with the specified name in DOSBox directory listings
bool boxer_shouldShowFileWithName(const char *name)
{
	NSString *fileName = [NSString stringWithCString: name encoding: BXDirectStringEncoding];
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldShowFileWithName: fileName];
}

//Whether to allow write access to the file at the specified path on the local filesystem
bool boxer_shouldAllowWriteAccessToPath(const char *path, DOS_Drive *dosboxDrive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldAllowWriteAccessToLocalPath: path onDOSBoxDrive: dosboxDrive];
}

//Tells Boxer to resync its cached drives - called by DOSBox functions that add/remove drives
void boxer_driveDidMount(uint8_t driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _syncDriveCache];
}

void boxer_driveDidUnmount(uint8_t driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _syncDriveCache];
}

void boxer_didCreateLocalFile(const char *path, DOS_Drive *dosboxDrive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didCreateFileAtLocalPath: path onDOSBoxDrive: dosboxDrive];
}

void boxer_didRemoveLocalFile(const char *path, DOS_Drive *dosboxDrive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didRemoveFileAtLocalPath: path onDOSBoxDrive: dosboxDrive];
}



FILE * boxer_openLocalFile(const char *path, DOS_Drive *drive, const char *mode)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _openFileAtLocalPath: path onDOSBoxDrive: drive inMode: mode];
}

bool boxer_removeLocalFile(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeFileAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_moveLocalFile(const char *fromPath, const char *toPath, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _moveLocalPath: fromPath toLocalPath: toPath onDOSBoxDrive: drive];
}

bool boxer_createLocalDir(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _createDirectoryAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_removeLocalDir(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeDirectoryAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_getLocalPathStats(const char *path, DOS_Drive *drive, struct stat *outStatus)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _getStats: outStatus forLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_localDirectoryExists(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localDirectoryExists: path onDOSBoxDrive: drive];
}

bool boxer_localFileExists(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localFileExists: path onDOSBoxDrive: drive];
}

#pragma mark Directory enumeration

void *boxer_openLocalDirectory(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    id <ADBFilesystemFileURLEnumeration> enumerator = [emulator _directoryEnumeratorForLocalPath: path
                                                                                        onDOSBoxDrive: drive];
    
    NSCAssert1(enumerator != nil, @"No enumerator found for %s", path);
    
    //Our own enumerators don't include directory entries for . and ..,
    //which are expected by DOSBox. So, we insert them ourselves during iteration.
    NSMutableArray *fakeEntries = [NSMutableArray arrayWithObjects: @".", @"..", nil];
    
    //The dictionary will be released when the calling context calls boxer_closeLocalDirectory() with the pointer to the dictionary.
    NSDictionary *enumeratorInfo = @{ @"enumerator": enumerator, @"fakeEntries": fakeEntries };
    
    return (void*)CFBridgingRetain(enumeratorInfo);
}

void boxer_closeLocalDirectory(void *handle)
{
    CFRelease(handle);
}

bool boxer_getNextDirectoryEntry(void *handle, char *outName, bool &isDirectory)
{
    NSDictionary *enumeratorInfo = (__bridge NSDictionary *)handle;
    NSMutableArray *fakeEntries = [enumeratorInfo objectForKey: @"fakeEntries"];
    
    if (fakeEntries.count)
    {
        const char *nextFakeEntry = [[fakeEntries objectAtIndex: 0] fileSystemRepresentation];
        strlcpy(outName, nextFakeEntry, CROSS_LEN);
        
        [fakeEntries removeObjectAtIndex: 0];
        isDirectory = YES;
        return true;
    }
    else
    {
        id <ADBFilesystemFileURLEnumeration> enumerator = [enumeratorInfo objectForKey: @"enumerator"];
        NSURL *nextURL = enumerator.nextObject;
        if (nextURL != nil)
        {
            NSNumber *directoryFlag = nil;
            NSString *fileName = nil;
            BOOL hasDirFlag = [nextURL getResourceValue: &directoryFlag forKey: NSURLIsDirectoryKey error: NULL];
            BOOL hasNameFlag = [nextURL getResourceValue: &fileName forKey: NSURLNameKey error: NULL];
            
            NSCAssert(hasNameFlag && hasDirFlag, @"Enumerator is missing directory and/or filename resources.");
            
            isDirectory = directoryFlag.boolValue;
            const char *nextEntry = fileName.fileSystemRepresentation;
            
            strlcpy(outName, nextEntry, CROSS_LEN);
            return true;
        }
        else return false;
    }
}


#pragma mark - Input functions

const char * boxer_preferredKeyboardLayout()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *layoutCode = emulator.keyboard.preferredLayout;
    
    if (layoutCode)
        return [layoutCode cStringUsingEncoding: BXDirectStringEncoding];
    else return NULL;
}

Bitu boxer_numKeyCodesInPasteBuffer()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.keyBuffer.count;
}

bool boxer_continueListeningForKeyEvents()
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    if (emulator.isCancelled || (emulator.isWaitingForCommandInput && emulator.commandQueue.count))
    {
        return false;
    }
    return true;
}

bool boxer_getNextKeyCodeInPasteBuffer(uint16_t *outKeyCode, bool consumeKey)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    
    [emulator _polledBIOSKeyBuffer];
    
    UInt16 keyCode = (consumeKey) ? emulator.keyBuffer.nextKey : emulator.keyBuffer.currentKey;
    if (keyCode != BXNoKey)
    {
        *outKeyCode = keyCode;
        return true;
    }
    else return false;
}

void boxer_setMouseActive(bool mouseActive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.mouse.active = mouseActive;
}

void boxer_setJoystickActive(bool joystickActive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.joystickActive = joystickActive;
}

void boxer_mouseMovedToPoint(float x, float y)
{
	NSPoint point = NSMakePoint((CGFloat)x, (CGFloat)y);
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.mouse.position = point;
}

void boxer_setCapsLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.capsLockEnabled = active;
}

void boxer_setNumLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.numLockEnabled = active;
}

void boxer_setScrollLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.scrollLockEnabled = active;
}


#pragma mark - Printer functions

Bitu boxer_PRINTER_readdata(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.dataRegister;
}

void boxer_PRINTER_writedata(Bitu port,Bitu val,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.printer.dataRegister = val;
}

Bitu boxer_PRINTER_readstatus(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.statusRegister;
}

void boxer_PRINTER_writecontrol(Bitu port,Bitu val, Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.printer.controlRegister = val;
}

Bitu boxer_PRINTER_readcontrol(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.controlRegister;
}

bool boxer_PRINTER_isInited(Bitu port)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    //Tell the emulator we actually want a printer
    [emulator _didRequestPrinterOnLPTPort: port];
    return emulator.printer != nil;
}

#pragma mark - Helper functions

//Return a localized string for the given DOSBox translation key
//This is called by MSG_Get in DOSBox's misc/messages.cpp, instead of retrieving strings from its own localisation system
const char * boxer_localizedStringForKey(char const *keyStr)
{
	NSString *theKey			= [NSString stringWithCString: keyStr encoding: BXDirectStringEncoding];
	NSString *localizedString	= [[NSBundle mainBundle]
								   localizedStringForKey: theKey
								   value: @"" //If the key isn't found, display nothing
								   table: @"DOSBox"];
	
	return [localizedString cStringUsingEncoding: BXDisplayStringEncoding];
}

void boxer_log(char const* format,...)
{
#ifdef BOXER_DEBUG
	//Copypasta from sdlmain.cpp
	char buf[512];
	va_list msg;
	va_start(msg,format);
	vsnprintf(buf,sizeof(buf)-1,format,msg);
	strcat(buf,"\n");
	va_end(msg);
	printf("%s",buf);
#endif
}

void boxer_die(const char *functionName, const char *fileName, int lineNumber, const char * format,...)
{
    char errorReason[1024];
	va_list params;
	va_start(params, format);
	vsnprintf(errorReason, sizeof(errorReason), format, params);
	va_end(params);
    
    throw boxer_emulatorException(errorReason, fileName, functionName, lineNumber);
}

void restart_program(std::vector<std::string> & parameters) {
    // TODO: re-write?
    E_Exit("Restarting not implemented!");
}

const char *DOSBOX_GetDetailedVersion() noexcept
{
    return "Boxer-build";
}

#pragma mark - No-ops

//These used to be defined in sdl_mapper.cpp, which we no longer include in Boxer.
void MAPPER_AddHandler(MAPPER_Handler *handler, SDL_Scancode key, uint32_t mods,
                       const char *event_name, const char *button_name) {}
void MAPPER_Init(void) {}
void MAPPER_StartUp(Section * sec) {}
void MAPPER_Run(bool pressed) {}
void MAPPER_RunInternal() {}
void MAPPER_LosingFocus(void) {}
void MAPPER_AutoType(std::vector<std::string> &sequence,
                     const uint32_t wait_ms,
                     const uint32_t pacing_ms) {}
std::vector<std::string> MAPPER_GetEventNames(const std::string &prefix) {return std::vector<std::string>();}
