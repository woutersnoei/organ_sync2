(
~organ_sync.makeWindow = { |evt|
	var w, views = (), update, updateMIDI, ctrl;
	if( evt.win.notNil && { evt.win.isClosed.not } ) {
		evt.win.close;
	};
	w = Window( "organ_sync", Rect(200,200, 420, 400) ).front;
	w.asView.minWidth_( 420 ).maxWidth_(420).minHeight_( 456 );
	w.addFlowLayout;

	evt.aoo.makeWindow( w );

	evt.aoo.win.background = Color.gray(0.8);

	w.asView.decorator.nextLine;

	StaticText( w, 420@20 )
	.resize_(7).string_( "Local organ").align_( \center )
	.font_( Font( Font.defaultSansFace, 12, true ) );

	StaticText( w, 100@20 )
	.resize_(7).string_( "mode:").align_( \right );

	views[ \mode ] = PopUpMenu( w, 75@20 )
	.resize_(7)
	.items_([ 'osc', 'midi', 'off' ])
	.action_({ |pu|
		evt.localSetting.mode = [ \osc, \midi, \off ][ pu.value ];
		evt.changed( \localSetting );
	});

	views[ \manuals ] = PopUpMenu( w, 125@20 )
	.resize_(7)
	.items_([ "no manuals", "1 manual" ] ++ (2..16).collect({ |item| "% manuals".format( item ) }) )
	.action_({ |pu|
		evt.localSetting.manuals = pu.value;
		evt.changed( \localSetting );
		evt.aoo.sendMetadata;
	});

	views[ \localThru ] = Button( w, 100@20 )
	.resize_(7)
	.states_([
		[ "local thru", Color.black, Color.red(0.7).blend( Color.white, 0.7 ) ],
		[ "local thru", Color.black, Color.green(0.7).blend( Color.white, 0.7 ) ]
	])
	.action_({ |bt|
		evt.localSetting.localThru = bt.value.booleanValue;
		evt.changed( \localSetting );
	});

	StaticText( w, 100@20 )
	.resize_(7).string_( "MIDI in:").align_( \right );

	views[ \midiIn ] = PopUpMenu( w, 308@20 )
	.resize_(7)
	.action_({ |pu|
		var item;
		item = pu.item;
		if( item.isKindOf( Symbol ) ) {
			evt.localSetting.midiIn = item;
		} {
			evt.localSetting.midiIn = nil;
		};
		evt.changed( \localSetting );
	});

	w.asView.decorator.nextLine;

	StaticText( w, 100@20 )
	.resize_(7).string_( "MIDI out:").align_( \right );

	views[ \midiOut ] = PopUpMenu( w, 308@20 )
	.resize_(7)
	.action_({ |pu|
		var item;
		item = pu.item;
		if( item.isKindOf( Symbol ) ) {
			evt.localSetting.midiOut = item;
		} {
			evt.localSetting.midiOut = nil;
		};
		evt.makeMIDIOut;
		evt.changed( \localSetting );
	});

	updateMIDI = {
		views[ \midiIn ].items_( [ \all ] ++ evt.midiDict.in.list ++ [ "none (off)" ] );
		views[ \midiOut ].items_( evt.midiDict.out.list ++ [ "none (off)" ] )
	};

	update = {
		views[ \mode ].value_( [ \osc, \midi, \off ].indexOf( evt.localSetting.mode ) ? 2 );
		views[ \manuals ].value_( evt.localSetting.manuals );
		views[ \localThru ].value_( evt.localSetting.localThru.binaryValue ? 0 );
		views[ \midiIn ].value = views[ \midiIn ].items
		.indexOf( evt.localSetting.midiIn ) ?? { views[ \midiIn ].items.size - 1 };
		views[ \midiOut ].value = views[ \midiOut ].items
		.indexOf( evt.localSetting.midiOut ) ?? { views[ \midiOut ].items.size - 1 };
		views[ \midiOut ].enabled = evt.localSetting.mode == \midi;
	};

	updateMIDI.value;
	update.value;

	w.asView.decorator.nextLine;

	StaticText( w, 100@20 )
	.resize_(7).string_( "MIDI mapping:").align_( \right );

	Button( w, 150 @ 20 )
	.states_([[ "remote" ]])
	.action_({ evt.makeRemoteMappingWindow; });

	w.asView.decorator.nextLine;
	w.asView.decorator.shift( 312 );

	Button( w, 100 @ 20 )
	.states_([[ "save" ]])
	.action_({ evt.storeSettings; });

	ctrl = SimpleController( evt )
	.put( \localSetting, { { update.value }.defer })
	.put( \midiDict,  { { updateMIDI.value; update.value }.defer } );

	w.onClose_({ ctrl.remove });

	evt.win = w;
	evt.views = views;
};

~organ_sync.makeRemoteMappingWindow = { |evt|
	var w, views = (), update, filterList, ctrl;
	var manualList, remoteSetting, numManuals;
	var windowHeight, windowBounds = Rect(200,200, 420, 400);
	if( evt.rmWin.notNil && { evt.rmWin.isClosed.not } ) {
		windowBounds = evt.rmWin.bounds;
		evt.rmWin.close;
	};
	windowBounds.height = evt.aoo.knownPeers.collect({ |item|
		((item.metadata !? _.manuals ? 4) * 20) + 20 + 20
	}).sum - 6;
	w = Window( "remote MIDI mapping", windowBounds, false ).front;
	w.addFlowLayout;

	manualList = [ "P" ] ++ (1..15).collect( "M" ++ _ );

	remoteSetting = { |name|
		if( evt.remoteSettings[ name ].isNil ) {
			evt.remoteSettings[ name ] = ();
		};
		evt.remoteSettings[ name ];
	};

	filterList = [ \note, \cc, \program, \sysex ];

	evt.aoo.knownPeers.do({ |item|
		var numManuals = item.metadata !? _.manuals ? 4;
		views[ item.name ] = ();
		StaticText( w, 104 @ 16 )
		.string_( item.name )
		.align_( \center )
		.font_( Font( Font.defaultSansFace, 12, true ) );
		views[ item.name ][ \filter ] = filterList.collect({ |key, i|
			Button( w, ((304 - ((filterList.size - 1)*4)) / filterList.size).floor.asInteger @ 16 )
			.states_([
				[ key, Color.black, Color.green(0.7).blend( Color.white, 0.7 ) ],
				[ key, Color.black, Color.red(0.7).blend( Color.white, 0.7 ) ],
			])
			.action_({ |bt|
				var filter;
				filter = remoteSetting.( item.name ).filter ?? {[]};
				switch( bt.value,
					1, { if( filter.includes( key ).not ) { filter = filter.add( key ) } },
					0, { filter.remove( key ); }
				);
				if( filter.size == 0 ) { filter = nil };
				remoteSetting.( item.name ).filter = filter;
				evt.changed( \remoteSettings );
			})
		});
		views[ item.name ].setFilter = { |evx|
			var filter;
			filter = remoteSetting.( item.name ).filter ?? {[]};
			filterList.do({ |key, i|
				views[ item.name ][ \filter ][i].value = filter.includes( key ).binaryValue;
			})
		};
		views[ item.name ].setFilter;
		w.asView.decorator.nextLine;
		views[ item.name ][ \manuals ] = numManuals.collect({ |manual|
			var vws = ();
			StaticText( w, 50 @ 16 )
			.string_( manualList[ manual ] )
			.align_( \center );
			vws[ \channel ] = PopUpMenu( w, 50 @ 16 )
			.items_( (1..16) ++ [ \any, \off ] )
			.action_({ |pu|
				var ch, midiChannels;
				switch( pu.value,
					16, { ch = 'any' },
					17, { ch = 'off' },
					{ ch = pu.value }
				);
				midiChannels = remoteSetting.( item.name ).midiChannels;
				if( ch == manual ) {
					if( midiChannels.size > manual ) {
						midiChannels[ manual ] = nil;
						while { midiChannels.last == nil && { midiChannels.size > 0 } } {
							midiChannels.pop
						};
						if( midiChannels.size == 0 ) { midiChannels = nil; }
					};
				} {
					if( midiChannels.size <= manual ) {
						midiChannels = (midiChannels ?? {[]}).extend( manual+1, nil );
					};
					midiChannels[ manual ] = ch;
				};
				remoteSetting.( item.name ).midiChannels = midiChannels;
				evt.changed( \remoteSettings );
			});
			vws.setChannel = { |evx|
				var val;
				val = (remoteSetting.( item.name ).midiChannels ?? {[]})[ manual ] ? manual;
				switch( val,
					\any, { val = 16 },
					\off, { val = 17 },
				);
				evx.channel.value = val;
			};
			vws.setChannel;
			vws[ \device ] = PopUpMenu( w, 304 @ 16 )
			.items_([ 'any device' ] ++ evt.midiDict.in.list);
			if( manual == 0 ) {
				vws[ \device ].action = { |pu|
					var device;
					device = remoteSetting.( item.name ).device;
					if( device.isArray.not ) {
						device = switch( pu.item,
							'any device', { nil },
							{ pu.item }
						);
					} {
						if( device.size <= manual ) { device = device.extend( manual+1, nil ) };
						device[ manual ] = switch( pu.item,
							'any device', { nil },
							{ pu.item }
						);
						if( device.every(_ == device[0]) ) { device = device[0] };
					};
					remoteSetting.( item.name ).device = device;
					evt.changed( \remoteSettings );
				};
			} {
				vws[ \device ].action = { |pu|
					var device;
					device = remoteSetting.( item.name ).device;
					if( device.isArray.not ) { device = device ! numManuals };
					if( device.size <= manual ) { device = device.extend( manual+1, nil ) };
					device[ manual ] = switch( pu.item,
						'any device', { nil },
						{ pu.item }
					);
					if( device.every(_ == device[0]) ) { device = device[0] };
					remoteSetting.( item.name ).device = device;
					evt.changed( \remoteSettings );
				};
			};
			vws.setDevice = { |evt|
				var device;
				device = remoteSetting.( item.name ).device;
				case { device.isNil } {
					vws[ \device ].value = 0
				} { device.isKindOf( Symbol ) } {
					vws[ \device ].value = vws[ \device ].items.indexOf( device ) ? 0
				} { device.isArray } {
					vws[ \device ].value = vws[ \device ].items.indexOf( device[ manual ] ) ? 0
				};
			};
			vws.setDevice;
			w.asView.decorator.nextLine;
			vws;
		});
		w.asView.decorator.shift( 0, 20 );
	});

	ctrl = SimpleController( evt )
	.put( \remoteSettings, {
		{
			views.keysValuesDo({ |key, val|
				val.setFilter;
				val.manuals.do({ |man|
					man.setChannel;
					man.setDevice;
				})
			});
		}.defer;
	});

	w.onClose_({ ctrl.remove });

	evt.rmWin = w;
	evt.rmViews = views;
};

);

/*

~organ_sync.makeRemoteMappingWindow;

~organ_sync.remoteSettings[ \Pi ]

device = nil;

~organ_sync.aoo.knownPeers = ~organ_sync.aoo.knownPeers.add( ( name: "SomeoneElsXXe" ) );
~organ_sync.aoo.changed( \knownPeers )

*/