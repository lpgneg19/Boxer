//
//  BXMIDISynth.swift
//  Boxer
//
//  Created by C.W. Betts on 4/25/18.
//  Copyright © 2018 Alun Bestor and contributors. All rights reserved.
//

import Foundation
import AudioToolbox

/// BXMIDISyth sending MIDI signals from DOSBox to OS X's built-in MIDI synth, using the AUGraph API.
/// It's largely cribbed from DOSBox's own coreaudio MIDI handler.
class BXMIDISynth : NSObject, BXMIDIDevice {
    private var graph: AUGraph?
    private var synthUnit: AudioUnit?
    private var outputUnit: AudioUnit?
    
    /// The URL of the soundfont bank we are currently using,
    /// which be the default system unless a custom one has been
    /// set with \c loadSoundFontWithContentsOfURL:error:
    private(set) var soundFontURL: URL
    
    
    /// Returns the URL of the default system soundfont.
    class var defaultSoundFontURL: URL? {
        guard let coreAudioBundle = Bundle(identifier: "com.apple.audio.units.Components"),
            let soundFontURL = coreAudioBundle.url(forResource: "gs_instruments", withExtension: "dls") else {
                fatalError("Default CoreAudio soundfont could not be found.")
        }
        return soundFontURL
    }
    
    private override init() {
        soundFontURL = BXMIDISynth.defaultSoundFontURL!
    }
    
    /// Returns a fully-initialized synth ready to receive MIDI messages.
    /// Returns nil and populates outError if the synth could not be initialised.
    @objc(initWithError:)
    public convenience init(error: ()) throws {
        self.init()
        try prepareAudioGraph()
    }
    
    
    /// Sets the specified soundfont with which MIDI should be played back.
    /// `soundFontURL` will be updated with the specified URL.
    /// Pass `nil` as the path to clear a previous custom soundfont and revert
    /// to using the system soundfont.
    /// Returns \c YES if the soundfont was loaded/cleared, or \c NO and populates
    /// `outError` if the soundfont couldn't be loaded for any reason (in which
    /// case `soundFontURL` will remain unchanged.)
    @objc(loadSoundFontWithContentsOfURL:error:)
    func loadSoundFont(withContentsOf URL: URL?) throws {
        
    }
    
    var volume: Float {
        get {
            return 0
        }
        set {
            
        }
    }
    
    var isProcessing: Bool {
        return false
    }

    
    var supportsMT32Music: Bool {
        return false
    }
    
    var supportsGeneralMIDIMusic: Bool {
        return true
    }
    
    func dateWhenReady() -> Date {
        return Date.distantPast
    }
    
    func handleMessage(_ message: Data) {
        fatalError()
    }
    
    func handleSysex(_ message: Data) {
        fatalError()
    }
    
    func pause() {
        fatalError()
    }
    
    func resume() {
        fatalError()
    }
    
    deinit {
        close()
    }
    
    func close() {
        if let _graph = graph {
            AUGraphStop(_graph)
            DisposeAUGraph(_graph)
        }
        graph = nil
        synthUnit = nil
        outputUnit = nil
    }

    private func prepareAudioGraph() throws {
        //OS X's default CoreAudio output
        var outputDesc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_DefaultOutput, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        
        //OS X's built-in MIDI synth
        var synthDesc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: kAudioUnitSubType_DLSSynth, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        
        func REQUIRE(_ blk: @autoclosure () -> OSStatus) throws {
            let iErr = blk()
            if iErr != noErr {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(iErr))
            }
        }
        
        do {
            var outputNode: AUNode = 0
            var synthNode: AUNode = 0
            
            try REQUIRE(NewAUGraph(&graph));
            //Create nodes for our input synth and our output, and connect them together
            try REQUIRE(AUGraphAddNode(graph!, &outputDesc, &outputNode));
            try REQUIRE(AUGraphAddNode(graph!, &synthDesc, &synthNode));
            try REQUIRE(AUGraphConnectNodeInput(graph!, synthNode, 0, outputNode, 0));
            
            //Open and initialize the graph and its units
            try REQUIRE(AUGraphOpen(graph!));
            try REQUIRE(AUGraphInitialize(graph!));
            
            //Get proper references to the audio units for the synth.
            try REQUIRE(AUGraphNodeInfo(graph!, synthNode, nil, &synthUnit));
            try REQUIRE(AUGraphNodeInfo(graph!, outputNode, nil, &outputUnit));
            
            //Finally start processing the graph.
            //(Technically, we could move this to the first time we receive a MIDI message.)
            try REQUIRE(AUGraphStart(graph!));

        } catch {
            //Clean up after ourselves if there was an error
            if let graph = graph {
                DisposeAUGraph(graph)
                self.graph = nil
                synthUnit = nil
                outputUnit = nil
            }
            throw error
        }
    }
}
