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
		[ "local thru", Color.black, Color.green(0.7) ]
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

	ctrl = SimpleController( evt )
	.put( \localSetting, { { update.value }.defer })
	.put( \midiDict,  { { updateMIDI.value; update.value }.defer } );

	w.onClose_({ ctrl.remove });

	evt.win = w;
	evt.views = views;
};
);