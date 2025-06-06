(
~organ_sync.makeWindow = { |evt|
	var w, views = (), update, updateMIDI, checkMIDI, ctrl;
	if( evt.win.notNil && { evt.win.isClosed.not } ) {
		evt.win.close;
	};
	w = Window( evt.envirName.asString, Rect(200,200, 420, 400) ).front;
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
		evt.changed( \localSetting, \mode );
		evt.aoo.sendMetadata;
	});

	views[ \manuals ] = PopUpMenu( w, 125@20 )
	.resize_(7)
	.items_([ "no manuals", "1 manual" ] ++ (2..16).collect({ |item| "% manuals".format( item ) }) )
	.action_({ |pu|
		evt.localSetting.manuals = pu.value;
		evt.changed( \localSetting, \manuals );
		evt.aoo.sendMetadata;
	});

	views[ \layers ] = PopUpMenu( w, 100@20 )
	.resize_(7)
	.items_([ "no layers", "1 layer" ] ++ (2..9).collect({ |item| "% layers".format( item ) }) )
	.action_({ |pu|
		evt.localSetting.layers = ([nil] ++ (1..9))[ pu.value ];
		evt.changed( \localSetting, \layers );
		evt.aoo.sendMetadata;
	});

	StaticText( w, 100@20 )
	.resize_(7).string_( "MIDI in:").align_( \right );

	views[ \midiIn ] = PopUpMenu( w, 204@20 )
	.resize_(7)
	.allowsReselection_( true )
	.action_({ |pu|
		var item;
		item = pu.item;
		if( item.isKindOf( Symbol ) ) {
			evt.localSetting.midiIn = item;
		} {
			if( item == "multiple..." ) {
				evt.makeMIDIInWindow;
			} {
				evt.localSetting.midiIn = nil;
			};
		};
		evt.changed( \localSetting, \midiIn );
	});

	views[ \localThru ] = Button( w, 100@20 )
	.resize_(7)
	.states_([
		[ "local thru", Color.black, Color.red(0.7).blend( Color.white, 0.7 ) ],
		[ "local thru", Color.black, Color.green(0.7).blend( Color.white, 0.7 ) ]
	])
	.action_({ |bt|
		evt.localSetting.localThru = bt.value.booleanValue;
		evt.changed( \localSetting, \localThru );
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
		evt.changed( \localSetting, \midiOut );
	});

	checkMIDI = { |which = \midiIn, trueFunc, falseFunc| // check if midi i/o exists
		if( [ nil, \all ].includes( evt.localSetting[ which ] ) or: {
			evt.midiDict[ ( \midiIn: \in, \midiOut: \out )[ which ] ]
			.list.includes( evt.localSetting[ which ] )
		}, trueFunc, falseFunc );
	};

	updateMIDI = {
		checkMIDI.( \midiIn, {
			views[ \midiIn ].items_( [ \all ] ++ evt.midiDict.in.list ++ [ "multiple...", "none (off)" ] );
		}, {
			if( evt.localSetting.midiIn.size > 1 ) {
				views[ \midiIn ].items_( [ \all ] ++ evt.midiDict.in.list ++ [ "multiple...", "none (off)" ] );
			} {
				views[ \midiIn ].items_( [ \all ] ++ evt.midiDict.in.list ++ [ evt.localSetting.midiIn, "multiple...", "none (off)" ] );
			};
		});

		checkMIDI.( \midiOut, {
			views[ \midiOut ].items_( evt.midiDict.out.list ++ [ "none (off)" ] );
		}, {
			views[ \midiOut ].items_( evt.midiDict.out.list ++ [ evt.localSetting.midiOut, "none (off)" ] );
		});
	};

	update = {
		views[ \mode ].value_( [ \osc, \midi, \off ].indexOf( evt.localSetting.mode ) ? 2 );
		views[ \manuals ].value_( evt.localSetting.manuals );
		views[ \layers ].value_( evt.localSetting.layers ? 0 );
		views[ \localThru ].value_( evt.localSetting.localThru.binaryValue ? 0 );

		checkMIDI.( \midiIn, {
			views[ \midiIn ].value = views[ \midiIn ].items
			.indexOf( evt.localSetting.midiIn ) ?? {
				if( evt.localSetting.midiIn.size > 1 ) {
					views[ \midiIn ].items.size - 2;
				} {
					views[ \midiIn ].items.size - 1;
				};
			};
			views[ \midiIn ].stringColor = nil;
		}, {
			if( evt.localSetting.midiIn.size > 1 ) {
				views[ \midiIn ].value = views[ \midiIn ].items.size - 2;
			} {
				if( views[ \midiIn ].items.includes( evt.localSetting.midiIn ).not ) {
					updateMIDI.value;
				};
				views[ \midiIn ].value = views[ \midiIn ].items.indexOf( evt.localSetting.midiIn );
				views[ \midiIn ].stringColor = Color.red;
			};
		});

		views[ \midiOut ].enabled = evt.localSetting.mode == \midi;
		views[ \local_mapping ].enabled = evt.localSetting.mode == \midi;
		views[ \layers ].enabled = evt.localSetting.mode == \osc;

		checkMIDI.( \midiOut, {
			views[ \midiOut ].value = views[ \midiOut ].items
			.indexOf( evt.localSetting.midiOut ) ?? { views[ \midiOut ].items.size - 1 };
			if( views[ \midiOut ].enabled ) {
				views[ \midiOut ].stringColor = Color.black;
			} {
				views[ \midiOut ].stringColor = Color.gray;
			};
		}, {
			if( views[ \midiOut ].items.includes( evt.localSetting.midiOut ).not ) {
				updateMIDI.value;
			};
			views[ \midiOut ].value = views[ \midiOut ].items
			.indexOf( evt.localSetting.midiOut ) ?? { views[ \midiOut ].items.size - 1 };
			if( views[ \midiOut ].enabled ) {
				views[ \midiOut ].stringColor = Color.red;
			} {
				views[ \midiOut ].stringColor = Color.red.blend( Color.gray, 0.9 );
			};
		});
	};

	w.asView.decorator.nextLine;

	StaticText( w, 100@20 )
	.resize_(7).string_( "MIDI mapping:").align_( \right );

	Button( w, 152 @ 20 )
	.states_([[ "remote mapping" ]])
	.resize_(7)
	.action_({ evt.makeRemoteMappingWindow; });

	views[ \local_mapping ] = Button( w, 152 @ 20 )
	.states_([[ "local mapping" ]])
	.resize_(7)
	.action_({ evt.makeLocalMappingWindow; });

	w.asView.decorator.nextLine;

	StaticText( w, 100@20 )
	.resize_(7).string_( "End all notes:").align_( \right );

	Button( w, 152 @ 20 )
	.states_([[ "remote panic" ]])
	.resize_(7)
	.action_({ evt.remoteEndAllNotes; });

	Button( w, 152 @ 20 )
	.states_([[ "local panic" ]])
	.resize_(7)
	.action_({ evt.localEndAllNotes; });

	w.asView.decorator.nextLine;

	StaticText( w, 100@20 )
	.resize_(7).string_( "").align_( \right );

	Button( w, 100 @ 20 )
	.states_([[ "refresh MIDI" ]])
	.resize_(7)
	.action_({
		evt.makeMIDISourceDicts( true );
		evt.makeMIDIOut;
	});

	w.asView.decorator.shift( 312 - 208 );

	Button( w, 100 @ 20 )
	.states_([[ "save" ]])
	.resize_(7)
	.action_({ evt.storeSettings; });

	ctrl = SimpleController( evt )
	.put( \localSetting, { { update.value }.defer })
	.put( \midiDict,  { { updateMIDI.value; update.value }.defer } );

	updateMIDI.value;
	update.value;

	w.onClose_({ ctrl.remove });

	evt.win = w;
	evt.views = views;
};

~organ_sync.makeRemoteMappingWindow = { |evt|
	var w, views = (), update, filterList, ctrl;
	var manualList, remoteSetting, numManuals, getNumLayers;
	var windowHeight, windowBounds = Rect(200,200, 420, 400);
	if( evt.rmWin.notNil && { evt.rmWin.isClosed.not } ) {
		windowBounds = evt.rmWin.bounds;
		evt.rmWin.close;
	};

	remoteSetting = { |name|
		if( evt.remoteSettings[ name ].isNil ) {
			evt.remoteSettings[ name ] = ();
		};
		evt.remoteSettings[ name ];
	};

	getNumLayers = { |knownPeer|
		if( remoteSetting.( knownPeer.name ).useLayers != false ) {
			(knownPeer.metadata !? _.layers ? 1).max(1)
		} {
			1
		}
	};

	windowBounds.height = (evt.aoo.knownPeers ? []).collect({ |item|
		((item.metadata !? _.manuals ? 4) * getNumLayers.(item) * 20) + 20 + 20
	}).sum - 6;
	w = Window( "to remote MIDI mapping", windowBounds, false ).front;
	w.addFlowLayout;

	manualList = [ "P" ] ++ (1..15).collect( "M" ++ _ );

	filterList = [ \note, \cc, \program, \sysex ];

	evt.aoo.knownPeers.do({ |item|
		var numManuals = item.metadata !? _.manuals ? 4;
		var numLayers = getNumLayers.(item);
		if( numLayers > 1 ) {
			manualList = ([ "P" ] ++ (1..15).collect( "M" ++ _ )).collect({ |item|
				numLayers.collect({ |layer|
					"% / L%".format( item, layer+1 );
				});
			}).flatten(1);
		} {
			manualList = [ "P" ] ++ (1..15).collect( "M" ++ _ );
		};
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
				evt.changed( \remoteSettings, item.name, \filter );
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
		views[ item.name ][ \manuals ] = ( numManuals * numLayers.max(1) ).collect({ |manual|
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
				evt.changed( \remoteSettings, item.name, \channel );
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
					evt.changed( \remoteSettings, item.name, \device );
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
					evt.changed( \remoteSettings, item.name, \device );
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
	.put( \remoteSettings, { |obj, msg, which, type|
		{
			views.keysValuesDo({ |key, val|
				if( [ nil, key ].includes( which ) ) {
					if( [ nil, \filter ].includes( type ) ) { val.setFilter; };
					val.manuals.do({ |man|
						if( [ nil, \channel ].includes( type ) ) { man.setChannel; };
						if( [ nil, \device ].includes( type ) ) { man.setDevice; };
					})
				}
			});
		}.defer;
	});

	w.onClose_({ ctrl.remove });

	evt.rmWin = w;
	evt.rmViews = views;
};

~organ_sync.makeLocalMappingWindow = { |evt|
	var w, views = (), update, filterList, ctrl;
	var manualList;
	var windowHeight, windowBounds = Rect(200,200, 420, 200);
	var numManuals = evt.localSetting[ \manuals ] ? 4;

	if( evt.lcWin.notNil && { evt.lcWin.isClosed.not } ) {
		windowBounds = evt.lcWin.bounds;
		evt.lcWin.close;
	};
	windowBounds.height = (((evt.localSetting.manuals ? 4) / 4).ceil * 20) + 20 + 6;
	w = Window( "local out MIDI mapping", windowBounds, false ).front;
	w.addFlowLayout;

	manualList = [ "P" ] ++ (1..15).collect( "M" ++ _ );

	filterList = [ \note, \cc, \program, \sysex ];

	StaticText( w, 104 @ 16 )
	.string_( "Local" )
	.align_( \center )
	.font_( Font( Font.defaultSansFace, 12, true ) );
	views[ \filter ] = filterList.collect({ |key, i|
		Button( w, ((304 - ((filterList.size - 1)*4)) / filterList.size).floor.asInteger @ 16 )
		.states_([
			[ key, Color.black, Color.green(0.7).blend( Color.white, 0.7 ) ],
			[ key, Color.black, Color.red(0.7).blend( Color.white, 0.7 ) ],
		])
		.action_({ |bt|
			var filter;
			filter = evt.localSetting.filter ?? {[]};
			switch( bt.value,
				1, { if( filter.includes( key ).not ) { filter = filter.add( key ) } },
				0, { filter.remove( key ); }
			);
			if( filter.size == 0 ) { filter = nil };
			evt.localSetting.filter = filter;
			evt.changed( \localSetting, \filter );
		})
	});
	views.setFilter = { |evx|
		var filter;
		filter = evt.localSetting.filter ?? {[]};
		filterList.do({ |key, i|
			views[ \filter ][i].value = filter.includes( key ).binaryValue;
		})
	};
	views.setFilter;
	w.asView.decorator.nextLine;
	views[ \manuals ] = numManuals.collect({ |manual|
		var vws = ();
		StaticText( w, 48 @ 16 )
		.string_( manualList[ manual ] )
		.align_( \center );
		vws[ \channel ] = PopUpMenu( w, 48 @ 16 )
		.items_( (1..16) ++ [ \off ] )
		.action_({ |pu|
			var ch, midiChannels;
			switch( pu.value,
				16, { ch = 'off' },
				{ ch = pu.value }
			);
			midiChannels = evt.localSetting.midiChannels;
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
			evt.localSetting.midiChannels = midiChannels;
			evt.changed( \localSetting, \channel );
		});
		vws.setChannel = { |evx|
			var val;
			val = (evt.localSetting.midiChannels ?? {[]})[ manual ] ? manual;
			switch( val,
				\off, { val = 16 },
			);
			evx.channel.value = val;
		};
		vws.setChannel;
		if( ( manual % 4 ) == 3 ) { w.asView.decorator.nextLine; };
		vws;
	});

	ctrl = SimpleController( evt )
	.put( \localSetting, { |obj, msg, type|
		{
			if( [ nil, \filter ].includes( type ) ) { views.setFilter; };
			views.manuals.do({ |man|
				if( [ nil, \channel ].includes( type ) ) { man.setChannel; };
			})
		}.defer;
	});

	w.onClose_({ ctrl.remove });

	evt.lcWin = w;
	evt.lcViews = views;
};

~organ_sync.makeMIDIInWindow = { |evt|
	var w, views, update, ctrl;
	var action;
	var windowBounds = Rect(626 ,128, 400, 400);

	if( evt.midiInWin.notNil && { evt.midiInWin.isClosed.not } ) {
		windowBounds = evt.midiInWin.bounds;
		evt.midiInWin.close;
	};

	windowBounds.height = (MIDIClient.sources.size + 1.25) * 24;
	w = Window( "MIDI in filter", windowBounds, false ).front;
	w.addFlowLayout;

	action = {
		var boxes, indices;
		boxes = views.collect(_.value);
		case { boxes.every( _ == true) } {
			evt.localSetting.midiIn = \all;
		} { boxes.every(_ == false) } {
			evt.localSetting.midiIn = nil;
		} {
			indices = boxes.selectIndices( _ == true );
			if( indices.size == 1 ) {
				evt.localSetting.midiIn = views[ indices[0] ].string.asSymbol;
			} {
				evt.localSetting.midiIn = views[ indices ].collect({ |item| item.string.asSymbol });
			}
		};
		evt.changed( \localSetting );
	};

	Button( w, 100 @ 20 )
	.states_([["all"]])
	.action_({ views.do(_.value_(true)); action.value });
	Button( w, 100 @ 20 )
	.states_([["none"]])
	.action_({ views.do(_.value_(false)); action.value });
	views = MIDIClient.sources.collect({ |src|
		CheckBox( w, 392 @ 20, "%/%".format( src.device, src.name ) )
		.action_( action );
	});

	update = {
		var list;
		case { evt.localSetting.midiIn == \all } {
			views.do(_.value_( true ))
		} { evt.localSetting.midiIn == nil } {
			views.do(_.value_( false ))
		} {
			list = evt.localSetting.midiIn.asArray;
			views.do({ |vw|
				if( list.includes( vw.string.asSymbol ) ) {
					vw.value = true;
				} {
					vw.value = false;
				};
			});
		};
	};

	ctrl = SimpleController( evt )
	.put( \localSetting, { |obj, msg, which, type|
		{ update.value; }.defer;
	});

	w.onClose_({ ctrl.remove });

	evt.midiInWin = w;
	evt.midiInViews = views;
};
);

/*
~organ_sync.makeWindow;

~organ_sync.makeRemoteMappingWindow;

~organ_sync.makeLocalMappingWindow;

~organ_sync.remoteSettings[ \Pi ]

device = nil;

~organ_sync.aoo.knownPeers = ~organ_sync.aoo.knownPeers.add( ( name: "SomeoneElsXXe" ) );
~organ_sync.aoo.changed( \knownPeers )

*/