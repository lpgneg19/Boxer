/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionPrivate declares protected methods for BXSession and its subclasses.

#import "BXSession.h"

@class BXEmulatorConfiguration;
@class BXCloseAlert;
@class BXDrive;
@interface BXSession ()

#pragma mark -
#pragma mark Properties

//These have been overridden to make them internally writeable
@property (readwrite, retain, nonatomic) NSMutableDictionary *gameSettings;
@property (readwrite, copy, nonatomic) NSString *activeProgramPath;
@property (readwrite, retain, nonatomic) NSArray *drives;
@property (readwrite, retain, nonatomic) NSDictionary *executables;
@property (readwrite, retain, nonatomic) NSArray *documentation;

@property (readwrite, assign, nonatomic, getter=isEmulating) BOOL emulating;


#pragma mark -
#pragma mark Protected methods

//Create our BXEmulator instance and starts its main loop.
//Called internally by [BXSession start], deferred to the end of the main thread's event loop to prevent
//DOSBox blocking cleanup code.
- (void) _startEmulator;

//Apply our chain of DOSBox configuration files (preflight, autodetected, gamebox, launch) to the emulator.
- (void) _loadDOSBoxConfigurations;

//Set up the emulator context with drive mounts and drive-related configuration settings. Called in
//runPreflightCommands at the start of AUTOEXEC.BAT, before any other commands or settings are run.
- (void) _mountDrivesForSession;

//Start up the target program for this session (if any) and displays the program panel selector after this
//finishes. Called by runLaunchCommands at the end of AUTOEXEC.BAT.
- (void) _launchTarget;

//Called once the session has exited to save any DOSBox settings we have changed to the gamebox conf.
- (void) _saveConfiguration: (BXEmulatorConfiguration *)configuration toFile: (NSString *)filePath;

//Cleans up temporary files after the session is closed.
- (void) _cleanup;

//Callback for close alert. Confirms document close when window is closed or application is shut down. 
- (void) _closeAlertDidEnd: (BXCloseAlert *)alert
				returnCode: (int)returnCode
			   contextInfo: (NSInvocation *)callback;
@end
