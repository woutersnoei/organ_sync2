~organ_sync = ~organ_sync ? ();

~organ_sync.remoteSettings = ();

~organ_sync.sendLatency = 0.02; // 0.02 seems safe in most circumstances

~organ_sync.checkManuals = true;

~organ_sync.verbose = true;

~organ_sync.remoteSettings[ \Pi ] = (
	midiChannels: [ 0,1,2,3 ], // local midi channels mapped to remote manuals
	midiIn: nil, // local midi device mapped to manuals
	filter: nil, // array of types to filter (i.e. not send)
);

~organ_sync.localSetting = (
	mode: \osc, // \midi, \osc, \off
	manuals: 4,
	midiChannels: [ 0,1,2,3 ],
	localThru: false,
	midiIn: \all,
	midiOut: nil, // name of midiout device (nil is no midi out)
	filter: nil, // array of types to filter (i.e. not receive)
);

~organ_sync.coupleMetadata = { |evt|
	evt.aoo.metadata = { ( manuals: evt.localSetting.manuals ) };
};

// -------- initialization: -------------

~organ_sync.init = { |evt|
	evt.aoo =  evt.aoo ?? { ().parent_( ~aoo ); };
	evt.coupleMetadata;
	evt.loadSettings;
	evt.aoo.connect;
	evt.makeMIDIFuncs;
	evt.makeOSCFuncs;
	evt.makeWindow;
	evt.makeMIDIOut;
};

// -------- remotes: -------------

~organ_sync.sendRemoteMsg = { |evt, which, type = \note ...args| // \note, \cc, \program, \sysex, \midi, \osc
	var peer;
	if( which.isKindOf( AooPeer ) ) { peer = which };
	which = evt.aoo.findKnownPeer( which );
	if( which.notNil && { which.send != false }) {
		peer = peer ?? { evt.aoo.getClientPeer( which ); };
		switch( type,
			\note, {
				if( evt.checkManuals.not or: {
					args[0] < ( which.metadata !? {
						which.metadata.manuals ? inf
					} ? inf)
				}) {
					// manual, nn, velo (0 = off), dur (optional, in seconds)
					evt.aoo.sendMsg( peer, evt.sendLatency, [ \note ] ++ args );
				};
			}, {
				evt.aoo.sendMsg( peer, evt.sendLatency, [ type ] ++ args );
			}
		);
	};
};

~organ_sync.routeRemoteNote = { |evt, peer, device, chan = 0, func|
	var knownPeer, setting, numManuals, midiChannels;
	knownPeer = evt.aoo.findKnownPeer( peer );
	setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
	if( (setting.filter ? #[]).includes( \note ).not ) {
		numManuals = knownPeer.metadata !? { knownPeer.metadata.manuals ? 16 } ? 16;
		midiChannels = setting.midiChannels ? #[];
		numManuals.do({ |manual|
			var matchChannel, matchDevice;
			matchChannel = midiChannels[ manual ] ? manual;
			matchDevice = setting.device !? { |x| if( x.size > 0 ) { x[ manual ] } { x } } ? nil;
			if( [ \all, chan ].includes( matchChannel ) && {
				matchDevice.isNil or: { device == matchDevice }
			}) {
				func.value( manual, setting );
			};
		});
	};
};

~organ_sync.sendRemoteNote = { |evt, device, chan = 0, nn = 64, velo = 127, dur|
	evt.aoo.client.peers.do({ |peer|
		evt.routeRemoteNote( peer, device, chan, { |manual, setting|
			if( dur.notNil ) {
				evt.sendRemoteMsg( peer, \note, manual, nn, velo, dur );
			} {
				evt.sendRemoteMsg( peer, \note, manual, nn, velo );
			};
		})
	});
};

~organ_sync.sendRemoteCC = { |evt, chan = 0, cc = 64, value = 64|
	evt.aoo.client.peers.do({ |peer|
		var setting;
		setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
		if( (setting.filter ? #[]).includes( \cc ).not ) {
			evt.sendRemoteMsg( peer, \cc, chan, cc, value );
		};
	});
};

~organ_sync.sendRemoteProgram = { |evt, bank = 0, program|
	evt.aoo.client.peers.do({ |peer|
		var setting;
		setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
		if( (setting.filter ? #[]).includes( \program ).not ) {
			if( program.isNil ) {
				evt.sendRemoteMsg( peer, \program, bank ); // bank is actually program
			} {
				evt.sendRemoteMsg( peer, \program, bank, program );
			}
		};
	});
};

~organ_sync.sendRemoteSysEx = { |evt, packet|
	evt.aoo.client.peers.do({ |peer|
		var setting;
		setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
		if( (setting.filter ? #[]).includes( \sysex ).not ) {
			evt.sendRemoteMsg( peer, \sysex, packet );
		};
	});
};

~organ_sync.sendRemoteMIDI = { |evt ...data| // raw midi, only used by midi-based organs
	evt.aoo.client.peers.do({ |peer|
		var setting;
		setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
		if( (setting.filter ? #[]).includes( \midi ).not ) {
			evt.sendRemoteMsg( peer, \midi, *data );
		};
	});
};

~organ_sync.sendRemoteOSC = { |evt ...data| // raw OSC (to be passed directly to Sinua organs)
	evt.aoo.client.peers.do({ |peer|
		var setting;
		setting = evt.remoteSettings[ peer.user.name.asSymbol ] ?? {()};
		if( (setting.filter ? #[]).includes( \osc ).not ) {
			evt.sendRemoteMsg( peer, \osc, *data );
		};
	});
};

~organ_sync.remoteEndAllNotes = { |evt|
	evt.aoo.client.peers.do({ |peer|
		evt.sendRemoteMsg( peer, \endAll );
	});
};

// -------- local: -------------

~organ_sync.makeMIDIOut = { |evt|
	var endPoint;
	endPoint = evt.findMIDIEndPoint( \out, evt.localSetting.midiOut );
	if( endPoint.notNil ) {
		evt.midiOut = MIDIOut( 0, endPoint.uid ).latency_( 0 );
	} {
		evt.midiOut = ( // create spoof MIDIOut with warnings if no MIDI device detected
			\noteOn: { |evt ...args| "noteOn %: no MIDI device set or detected\n".postf( args ) },
			\control: { |evt ...args| "control %: no MIDI device set or detected\n".postf( args ) },
			\program: { |evt ...args| "program %: no MIDI device set or detected\n".postf( args ) },
			\sysex: { |evt ...args| "sysex %: no MIDI device set or detected\n".postf( args ) },
			\write: { |evt ...args| "midi data %: no MIDI device set or detected\n".postf( args ) },
		);
	};
};

~organ_sync.sendLocalNote = { |evt, manual = 0, nn = 64, velo = 127, dur| // nn can be Array
	var chan, auxChan;
	switch( evt.localSetting.mode,
		\osc, {
			~bo.note( manual, nil, nn, velo, dur );
		},
		\midi, {
			chan = (evt.localSetting.midiChannels ? #[])[ manual ] ? manual;
			if( chan.notNil ) {
				if( nn.isArray ) {
					nn.do({ |nx|
						evt.midiOut.noteOn( chan, nx, velo );
					});
				} {
					evt.midiOut.noteOn( chan, nn, velo );
				};
			};
			if( dur.notNil ) {
				{
					dur.wait;
					evt.sendLocalNote( manual, nn, 0 );
				}.fork;
			};
		}
	);
};

~organ_sync.sendLocalCC = { |evt, chan = 0, cc = 0, val = 64|
	switch( evt.localSetting.mode,
		\osc, {
			switch( cc.asInteger,
				// mimicks Orgelpark MIDI to OSC max patch
				1, {
					~bo.tremolo( 'ow', nil, val.linexp(0,127,0.005,12) );
				},
				2, {
					~bo.tremolo( 'ow', val.inclusivelyBetween(1,126), nil, val / 127 );
				},
				3, {
					~bo.tremolo( 'hw', nil, val.linexp(0,127,0.005,12) );
				},
				4, {
					~bo.tremolo( 'hw', val.inclusivelyBetween(1,126), nil, val / 127 );
				},
				5, {
					~bo.motorSpeed( val / 127 );
				},
				6, {
					~bo.crescendo( val / 127 );
				},
				7, {
					~bo.swell( val / 127 );
				}
			);
		},
		\midi, {
			evt.midiOut.control( chan, cc, val );
		}
	);
};

~organ_sync.sendLocalProgram = { |evt, bank = 0, program|
	switch( evt.localSetting.mode,
		\osc, {
			// to do
		},
		\midi, {
			if( program.notNil ) {
				evt.midiOut.control( 0, 0, bank );
				evt.midiOut.program( 0, program );
			} {
				evt.midiOut.program( 0, bank );
			};
		}
	);
};

~organ_sync.sendLocalSysEx = { |evt, packet|
	switch( evt.localSetting.mode,
		\osc, {
			if( evt.verbose ) { "OSC: sysex not supported".postln; };
		},
		\midi, {
			evt.midiOut.sysex( packet );
		}
	);
};

~organ_sync.sendLocalMIDI = { |evt ...data|
	switch( evt.localSetting.mode,
		\osc, {
			if( evt.verbose ) { "OSC: midi not supported".postln; };
		},
		\midi, {
			evt.midiOut.write( data.size, *data.collect(_.asInteger) );
		}
	);
};

~organ_sync.sendLocalOSC = { |evt ...data|
	switch( evt.localSetting.mode,
		\osc, {
			~bo.addr.sendMsg( *data );
		},
		\midi, {
			if( evt.verbose ) { "MIDI: osc not supported".postln; };
		}
	);
};


~organ_sync.localEndAllNotes = { |evt| // "panic"
	evt.localSetting.manuals.do({ |manual|
		evt.sendLocalNote( manual, (1..127), 0 );
	});
};

// -------- oscfuncs: -------------

~organ_sync.makeOSCFuncs = { |evt|
	[
		[ '/note', \sendLocalNote, \note ],
		[ '/cc', \sendLocalCC, \cc ],
		[ '/program', \sendLocalProgram, \program ],
		[ '/sysex', \sendLocalSysEx, \sysex ],
		[ '/midi', \sendLocalMIDI, \midi ],
		[ '/osc', \sendLocalOSC, \osc ],
		[ '/endAll', \localEndAllNotes, \endAll ],
	].do({ |arr|
		var key, cmd, type;
		#key, cmd, type = arr;
		evt.aoo.addOSCFunc({ |msg, time, peer, client|
			var knownPeer = evt.aoo.findKnownPeer( peer ) ?? { () };
			var filter;
			if( knownPeer.receive != false ) {
				filter = evt.localSetting !? _.filter;
				if( ( filter !? _.includes( type ) ? false ).not ) {
					SystemClock.schedAbs( time + ( knownPeer.latency ? 0 ), { |t|
						evt.perform( cmd, *msg[1..] );
						nil;
					});
				};
			};
		}, key )
	});
};

~organ_sync.removeOSCFuncs = { |evt|
	[ '/note', '/cc', '/program', '/sysex', '/midi', '/osc', '/endAll' ].do({ |key|
		evt.aoo.removeOSCFunc( key )
	});
};

// -------- midifuncs: -------------

~organ_sync.makeMIDISourceDicts = { |evt, restart = false| // lookup tables for quick access
	if( restart == true ) {
		MIDIClient.init;
	};
	evt.midiDict = (
		\in:  ( \uid: (), \device: (), \list: [] ),
		\out: ( \uid: (), \device: (), \list: [] ),
	);
	MIDIIn.connectAll;
	MIDIClient.sources.do({ |ep|
		var name ="%/%".format( ep.device, ep.name ).asSymbol;
		evt.midiDict.in.device.put( ep.uid, name );
		evt.midiDict.in.uid.put( name, ep.uid );
		evt.midiDict.in.list = evt.midiDict.in.list.add( name );
	});
	MIDIClient.destinations.do({ |ep|
		var name ="%/%".format( ep.device, ep.name ).asSymbol;
		evt.midiDict.out.device.put( ep.uid, name );
		evt.midiDict.out.uid.put( name, ep.uid );
		evt.midiDict.out.list = evt.midiDict.out.list.add( name );
	});
	evt.changed( \midiDict );
};

~organ_sync.findMIDIEndPoint = { |evt, mode = \in, name|
	if( name.isKindOf( Number ) ) {
		name = evt.midiDict[ mode ].list[ name ] ? name;
	};
	if( name.isKindOf( Symbol ) ) {
		name = evt.midiDict[ mode ].uid[ name ];
	};
	switch( mode,
		\in, { MIDIClient.sources.detect({ |item| item.uid == name }) },
		\out, { MIDIClient.destinations.detect({ |item| item.uid == name }) },
	);
};

~organ_sync.midiRespond = { |evt, uid, remoteFunc, localFunc|
	var device;
	device = evt.midiDict.in.device[ uid ] ? uid;
	if( evt.localSetting.midiIn == \all or: {
		evt.localSetting.midiIn.asArray.includes( device );
	} ) { remoteFunc.value( device ) };
	if( evt.localSetting.localThru == true, localFunc );
};

~organ_sync.makeMIDIFuncs = { |evt|
	evt.makeMIDISourceDicts;

	MIDIdef.noteOn( "%_%".format( evt.aoo.port, \noteOn ).asSymbol, { |val, num, chan, uid|
		evt.midiRespond( uid,
			{ |device| evt.sendRemoteNote( device, chan, num, val ); },
			{ evt.sendLocalNote( chan, num, val ); }
		);
	});

	MIDIdef.noteOff( "%_%".format( evt.aoo.port, \noteOff ).asSymbol, { |val, num, chan, uid|
		evt.midiRespond( uid,
			{ |device| evt.sendRemoteNote( device, chan, num, 0 );},
			{ evt.sendLocalNote( chan, num, 0 ); }
		);
	});

	MIDIdef.cc( "%_%".format( evt.aoo.port, \cc ).asSymbol, { |val, num, chan, uid|
		evt.midiRespond( uid,
			{ evt.sendRemoteCC( chan, num, val ); },
			{ evt.sendLocalCC( chan, num, val ); }
		);
	});

	MIDIdef.program( "%_%".format( evt.aoo.port, \program ).asSymbol, { |val, chan, uid|
		evt.midiRespond( uid,
			{ evt.sendRemoteProgram( val ); },
			{ evt.sendLocalProgram( val ); }
		);
	});

	MIDIdef.sysex( "%_%".format( evt.aoo.port, \sysex ).asSymbol, { |packet, uid|
		evt.midiRespond( uid,
			{ evt.sendRemoteSysEx( packet ); },
			{ evt.sendLocalSysEx( packet ); }
		);
	});
};

// -------- local OSC func -------------

~organ_sync.makeLocalOSCFunc = { |evt|
	var typeList = (
		'note': 'sendLocalNote',
		'cc': 'sendLocalCC',
		'program': 'sendLocalProgram',
		'sysex': 'sendLocalSysEx',
		'osc': 'sendLocalOSC',
		'midi': 'sendLocalMIDI',
		'endAll': 'localEndAllNotes'
	);
	OSCdef( 'organ_sync_local', { |msg|
		var peer, type;
		#peer, type = msg[[1,2]];
		switch( peer,
			\local, {
				evt.perform( typeList[ type ], *msg[3..] );
			},
			\all, {
				evt.aoo.peers.do({ |pr|
					evt.sendRemoteMsg( pr, type, *msg[3..] );
				});
			}, {
				evt.sendRemoteMsg( peer, type, *msg[3..] );
			}
		);
	}, '/organ_sync' );
};

// -------- store/read settings: -------------

~organ_sync.getSettings = { |evt|
	(
		localSetting: evt.localSetting,
		remoteSettings: evt.remoteSettings,
		userName: evt.aoo.userName,
		port: evt.aoo.port
	)
};

~organ_sync.applySettings = { |evt, settings|
	if( settings.notNil ) {
		evt.localSetting = settings.localSetting ? evt.localSetting;
		evt.remoteSettings = settings.remoteSettings ? evt.remoteSettings;
		evt.aoo.userName = settings.userName ? evt.aoo.userName;
		evt.aoo.port = settings.port ? evt.aoo.port;
	};
};

~organ_sync.settingsPath = Platform.userAppSupportDir +/+ "organ_sync_settings.scd";

~organ_sync.storeSettings = { |evt|
	File.use( evt.settingsPath, "w", { |f|
		f.putString( evt.getSettings.cs );
	});
	"stored settings to %\n".postf( evt.settingsPath );
};

~organ_sync.loadSettings = { |evt|
	if( File.exists( evt.settingsPath ) ) {
		evt.applySettings( evt.settingsPath.load );
		"loaded settings from %\n".postf( evt.settingsPath );
	};
};

/*

~organ_sync.makeMIDIFuncs;

~organ_sync.localSetting.localThru = false;
~organ_sync.localSetting.mode = \midi;

~organ_sync.sendToRemote( "Pi", \post, 0, $[, 64,65,66, $], 128 );
~organ_sync.checkManuals.not

x = (hello: { |evt, x| [ evt, x ].postln });

x.hello

y = ().parent_( x );

~organ_sync.sendLocalProgram( 1 )

~organ_sync.midiOut.program( 0, 0 )

MIDIIn.doNoteOnAction( nil, 0, 102, 11 );

MIDIIn.doNoteOffAction( nil, 1, 0, 127 );

MIDIIn.doControlAction( nil, 0, 7, 127 );

MIDIIn.doProgramAction( nil, 0, 9 );

y.hello(1)

[64,65,66]

 [\post, 0, [64,65,66], 128].asRawOSC

AooData( \osc, [\post, 0, [64,65,66], 128] );
*/