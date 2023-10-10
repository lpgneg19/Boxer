/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCoalface.h"
#include <string>

typedef enum {
    BXLeftChannel,
    BXRightChannel
} BXAudioChannel;

/// Tell BXEmulator the preferred MIDI handler according to the DOSBox configuration.
void boxer_suggestMIDIHandler(std::string const &handlerName, const char *configParams);

/// Tells DOSBox whether MIDI is currently available or not.
bool boxer_MIDIAvailable(void);

/// Dispatch MIDI messages sent from DOSBox's MPU-401 emulation.
void boxer_sendMIDIMessage(uint8_t *msg);
void boxer_sendMIDISysex(uint8_t *msg, Bitu len);

float boxer_masterVolume(BXAudioChannel channel);

/// Defined in mixer.cpp. Update the volumes of all active channels.
void boxer_updateVolumes();
