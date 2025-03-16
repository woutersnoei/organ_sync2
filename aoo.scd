(
// boot server first!

~aoo = ~aoo ? ();

~aoo.groupName = "ws-test";

~aoo.userName = nil; // <- change this to yours locally

~aoo.server = "aoo.iem.at";

~aoo.port = 9995;

~aoo.connect = { |evt, action, freeFirst = true|
	if( evt.userName.size > 0 ) {
		s.waitForBoot({
			fork {
				if( freeFirst ) {
					evt.client.free;
					evt.changed( \disconnected );
					s.sync;
				};
				evt.client = AooClient( evt.port );
				s.sync;
				evt.client.connect( evt.server, action: { |err|
					if (err.isNil) { // connected successfully! now join the group.
						evt.client.joinGroup( evt.groupName, evt.userName, action: { |err|
							if (err.isNil) {
								"%: successfully joined group '%'\n".postf( evt.userName, evt.groupName );
								action.value( evt );
								evt.changed( \connected );
								evt.client.removeListener( \msg );
								evt.client.addListener( \msg, { |obj, time, peer|
									evt.msgListen( obj, time, peer );
								});
								evt.client.addListener( \event, { |type, args|
									evt.eventListen( type, args );
								});
								evt.resetRTT;
								//{ evt.sendMetadata; }.defer(1);
							} {
								evt.changed( \disconnected );
							};
						} );
					}
				});
				evt.changed( \connecting );
			};
		});
	} {
		"AOO connect: please define your userName".postln;
		evt.changed( \disconnected );
	};
};

~aoo.eventListen = { |evt, type, args|
	switch( type,
		\peerPing, {
			evt.findKnownPeer( args[0] ) !? { |item|
				item.maxRTT = (item.maxRTT ? 0).max( args[3] );
				item.rtt = args[3];
				item.delta1 = args[1];
				item.delta2 = args[2];
				evt.changed( \knownPeersActive )
			};
		},
		\peerJoin, {
			evt.updatePeers;
			evt.sendMetadata( args );
		},
		\peerLeave, {
			evt.updatePeers;
		}
	)
};

~aoo.msgListen = { |evt, obj, time, peer|
	var knownPeer, timeOffset;
	if( obj.type === \json ) {
		evt.acceptMetadata( obj, peer );
		evt.changed( \knownPeersActive );
	};
	knownPeer = evt.findKnownPeer( peer );
	if( knownPeer.notNil ) {
		knownPeer.received_( true ).changed( \received );
		timeOffset = (time - Process.elapsedTime) + (knownPeer.latency ? 0);
		knownPeer.recvOffsets = knownPeer.recvOffsets.add( timeOffset );
		if( timeOffset < 0 ) { knownPeer.lates = (knownPeer.lates ? 0) + 1 };
		if( knownPeer.recvOffsets.size > 1024 ) {
			knownPeer.recvOffsets = knownPeer.recvOffsets[ knownPeer.recvOffsets.size - 1024 ..];
		};
	};
};

~aoo.end = { |evt|
	evt.client.free;
	evt.changed( \disconnected );
};

~aoo.dictToJSON = { |evt, dict|
	var objects = [] ;
	dict.keysValuesDo({ |key, value|
		objects = objects.add( "%: %".format( key, value ) );
	});
	"{ % }".format( objects.join( ", " ) )
};

~aoo.jsonToDict = { |evt, json, returnNilIfEmpty = true|
	var parsed, dict = ();
	parsed = json.parseJSON;
	parsed.keysValuesDo({ |key, value|
		if( value.every({ |item| "1234567890.e- ".includes(item) }) ) {
			value = { value.interpret }.try ? value;
		};
		dict.put( key.asSymbol, value );
	});
	if( returnNilIfEmpty.not or: { dict.size > 0 } ) {
		dict
	};
};

~aoo.sendMetadata = { |evt, peer|
	//"sending metadata to %\n".postf( peer ? "all peers");
	evt.sendMsg( peer, 0.0, AooData( \json, evt.dictToJSON( evt.metadata ? () ) ) );
};

~aoo.acceptMetadata = { |evt, data, peer|
	//"receiving metadata from %\n".postf( peer );
	if( data.isKindOf( AooData ) ) { data = data.data };
	evt.knownPeers.detect({ |item|
		item.peer.user.name == peer.user.name
	}) !? { |item| item.metadata = evt.jsonToDict( data ) };
};

~aoo.addOSCFunc = { |evt, func, key = '/test'|
	var name = "recv%_%".format( evt.userName, key ).asSymbol;
	evt.oscFuncCTRLs = evt.oscFuncCTRLs ?? {()};
	evt.oscFuncCTRLs[ key ].free;
	evt.oscFuncCTRLs[ key ] = SimpleController( evt )
	.put( \connected, {
		"adding OSCdef '%'\n".postf( name );
		OSCdef( name, func, key, dispatcher: evt.client.dispatcher );
	})
	.put( \disconnected, {
		"removing OSCdef '%'\n".postf( name );
		OSCdef( name ).free;
	});
	if( evt.client.notNil && { evt.client.state == \connected }) {
		evt.oscFuncCTRLs[ key ].update( evt, \connected );
	};
};

~aoo.removeOSCFunc = { |evt, key = '/test'|
	var name = "recv%_%".format( evt.userName, key ).asSymbol;
	OSCdef( name ).free;
	evt.oscFuncCTRLs !? { |x| x[ key ].remove; x[ key ] = nil };
};

~aoo.sendMsg = { |evt, peer, time, msg, reliable = false|
	var str;
	if( peer.isString or: { peer.isKindOf( Symbol ) } ) {
		str = peer.asString;
		peer = evt.client.peers.detect({ |item|
			item.user.name == str;
		});
		if( peer.isNil ) { "user '%' not found, sent to all instead\n".postf( str ); }
	};

	if( peer.isNil ) {
		evt.knownPeers.select({ |item| item.active == true }).do({ |item|
			item.sent_( true ).changed( \sent );
		});
	} {
		evt.findKnownPeer( peer ) !? { |item| item.sent_( true ).changed( \sent ); };
	};
};

~aoo.updatePeers = { |evt, reset = false|
	var changed = false, activeChanged = false;
	if( reset ) { evt.knownPeers = []; changed = true; };
	evt.client.peers.do({ |peer|
		if( (evt.knownPeers ? []).any({ |item| item.peer == peer }).not ) {
			evt.knownPeers = evt.knownPeers.add( ( peer: peer, active: true ) );
			changed = true;
		};
	});
	evt.knownPeers.do({ |item|
		var clientPeer;
		clientPeer = evt.client.peers.detect({ |peer| peer == item.peer });
		if( clientPeer.notNil ) {
			if( item.peer.user.name != clientPeer.user.name or: {
				item.peer.user.id != clientPeer.user.id
			}) {
				item.peer = clientPeer;
				changed = true;
			};
			if( item.active != true ) {
				item.active = true;
				activeChanged = true;
			};
		} {
			if( item.active != false ) {
				item.active = false;
				activeChanged = true;
			};
		};
	});
	if( changed ) {
		evt.changed( \knownPeers )
	} {
		if( activeChanged ) {
			evt.changed( \knownPeersActive )
		};
	};
};

~aoo.sortKnownPeers = { |evt|
	evt.knownPeers = evt.knownPeers.sort({ |a,b|
		a.peer.user.name <= (b.peer.user.name)
	});
	evt.changed( \knownPeers );
};

~aoo.menuFront = { |evt, menu, point, action|
	var tempAction;
	point = point ?? { QtGUI.cursorPosition; };
	action = action ?? { tempAction = MenuAction(); };
	menu.invokeMethod(\popup, [point, action]);
	tempAction !? _.destroy;
};

~aoo.menuDeepDestroy = { |evt, menu|
	menu.actions.do({ |act|
		if( act.menu.notNil ) {
			act.menu.deepDestroy;
		};
		act.destroy;
	});
	menu.destroy;
};

~aoo.findKnownPeer = { |evt, peer|
	if( peer.isKindOf( AooPeer ) ) {
		peer = peer.user.name;
	};
	evt.knownPeers.detect({ |item|
		item.peer.user.name == peer;
	});
};

~aoo.resetRTT = { |evt|
	evt.knownPeers.do({ |item|
		item.maxRTT = nil;
	})
};

(
~aoo.makeWindow = { |evt|
	var w, views = (), update, fillPeers, colorPeers, ctrl;
	if( evt.win.notNil && { evt.win.isClosed.not } ) {
		evt.win.close;
	};
	w = Window( "AOO : %".format( evt.server ), Rect(200,200, 420, 280) ).front;
	w.addFlowLayout;
	w.view.minWidth_( 420 ).minHeight_( 256 );

	StaticText( w, 100@20 )
	.string_( "userName: " )
	.align_( \right );
	views[ \userName ] = TextField( w, 100@20 )
	.string_( evt.userName ? "" )
	.keyUpAction_({ |vw|
		if( vw.string != evt.userName ) {
			vw.stringColor = Color.red;
		} {
			vw.stringColor = Color.black;
		}
	})
	.action_({ |vw|
		if( evt.userName != vw.string ) {
			evt.userName = vw.string;
			"changed userName to '%'\n".postf( evt.userName );
			vw.stringColor = Color.black;
			evt.changed( \userName );
			if( evt.client.notNil && { evt.client.groups.size > 0 }) {
				evt.connect;
			};
		};
	});

	views[ \status ] = StaticText( w, 100@20 )
	.string_( evt.groupName )
	.align_( \center )
	.background_(
		[
			Color.red(0.7),
			Color.green(0.7)
		][ (evt.client !? { |x| x.state == \connected } ? false).binaryValue ]
	);

	views[ \connect ] = Button( w, 100@20 )
	.states_([[ "connect" ],[ "disconnect" ]])
	.value_( (evt.client !? { |x| x.state == \connected } ? false).binaryValue )
	.action_({ |bt|
		switch( bt.value,
			1, { evt.connect; },
			0, {
				evt.end;
				evt.updatePeers(  );
			}
		);
	});

	views[ \comp ] = CompositeView( w, 412@224 ).background_( Color.gray(0.9) ).resize_(5);
	views[ \comp ].addFlowLayout;

	views[ \sort ] = Button( w, 100@20 )
	.states_([["sort"]])
	.resize_( 7 )
	.action_({
		evt.sortKnownPeers;
	});

	views[ \remove ] = Button( w, 100@20 )
	.states_([["remove inactive"]])
	.resize_( 7 )
	.action_({
		//evt.updatePeers( true );
		evt.knownPeers.removeAllSuchThat({ |item| item.active == false });
		evt.changed( \knownPeers );
	});

	views[ \resetRTT ] = Button( w, 100@20 )
	.states_([[ "reset RTT" ]])
	.resize_( 7 )
	.action_({
		evt.resetRTT;
	});

	fillPeers = {
		views[ \peers ].do({ |vws|
			vws[ \comp ].remove;
		});
		views[ \comp ].decorator.reset;
		views[ \peers ] = evt.knownPeers.collect({ |item, i|
			var vws = (), menu, removeMenu, ctl, exists = true;
			var rTask, sTask;
			vws[ \comp ] = CompositeView( views[ \comp ], (views[ \comp ].bounds.width - 8) @ 20 )
			.background_( Color.white )
			.resize_(2)
			.onClose_({
				exists = false;
				evt.menuDeepDestroy( menu );
				removeMenu = nil;
			});
			vws[ \txt ] = StaticText( vws[ \comp ], (vws[ \comp ].bounds.width - 40) @ 20 )
			.resize_(5)
			.background_( Color.hsv(
				(item.peer.user.name.hash % 2048).linlin( 0,2048, 0.0, 1.0 ), 0.1, 0.7 )
			)
			.string_( " % (%)".format( item.peer.user.name, item.peer.user.id ) );
			vws[ \send ] = StaticText( vws[ \comp ], Rect( vws[ \comp ].bounds.width - 40, 0, 20, 20 ) )
			.resize_(6)
			.string_( "s" )
			.align_( \center );
			vws[ \receive ] = StaticText( vws[ \comp ], Rect( vws[ \comp ].bounds.width - 20, 0, 20, 20 ) )
			.resize_(6)
			.string_( "r" )
			.align_( \center );
			menu = Menu(
				MenuAction.separator( " % (%) %".format(
					item.peer.user.name,
					item.peer.user.id,
					item.metadata ? ""
				) ),
				MenuAction( "Send".format( 100.rand ), { |act, bool|
					if( bool == true ) {
						vws[ \send ].stringColor = Color.black;
					} {
						vws[ \send ].stringColor = Color.gray( 0.5 );
					};
				})
				.checked_( true ),
				MenuAction( "Receive".format( 100.rand ), { |act, bool|
					if( bool == true ) {
						vws[ \receive ].stringColor = Color.black;
					} {
						vws[ \receive ].stringColor = Color.gray( 0.5 );
					};
				})
				.checked_( true ),
				MenuAction.separator,
				Menu(
					MenuAction( "To top", {
						var pr;
						pr = evt.knownPeers.removeAt( i );
						evt.knownPeers = evt.knownPeers.addFirst( pr );
						evt.changed( \knownPeers );
					})
					.enabled_( i > 0 ),
					MenuAction( "Up", {
						var pr;
						pr = evt.knownPeers.removeAt( i );
						evt.knownPeers = evt.knownPeers.insert( i-1, pr );
						evt.changed( \knownPeers );
					})
					.enabled_( i > 0 ),
					MenuAction( "Down", {
						var pr;
						pr = evt.knownPeers.removeAt( i );
						evt.knownPeers = evt.knownPeers.insert( i+1, pr );
						evt.changed( \knownPeers );
					})
					.enabled_( i < (evt.knownPeers.size-1) ),
					MenuAction( "To bottom", {
						var pr;
						pr = evt.knownPeers.removeAt( i );
						evt.knownPeers = evt.knownPeers.add( pr );
						evt.changed( \knownPeers );
					})
					.enabled_( i < (evt.knownPeers.size-1) ),
				).title_( "Move" ),
				removeMenu = MenuAction( "Remove", {
					evt.knownPeers.removeAt( i );
					evt.changed( \knownPeers );
				})
			);
			vws[ \txt ].mouseDownAction_({
				evt.menuFront( menu );
			});
			vws[ \setRemoveEnabled ] = { |vwx, bool = true|
				removeMenu !? _.enabled_(bool);
			};
			ctl = SimpleController( item )
			.put( \received, {
				if( rTask.isNil ) {
					rTask = {
						while {
							item.received == true
						} {
							item.received = false;
							if( vws[ \receive ].isClosed.not ) {
								vws[ \receive ].background_( Color.green );
							};
							0.25.wait;
						};
						if( vws[ \receive ].isClosed.not ) {
							vws[ \receive ].background_( Color.clear );
						};
						rTask = nil;
					}.fork( AppClock );
				};
			})
			.put( \sent, {
				if( sTask.isNil ) {
					sTask = {
						while {
							item.sent == true
						} {
							item.sent = false;
							if( vws[ \send ].isClosed.not ) {
								vws[ \send ].background_( Color.blue.blend( Color.white, 0.5 ) );
								0.25.wait;
							};
						};
						if( vws[ \send ].isClosed.not ) {
							vws[ \send ].background_( Color.clear );
						};
						sTask = nil;
					}.fork( AppClock );
				};
			});
			vws[ \comp ].onClose_({ ctl.remove });
			vws;
		});
	};

	colorPeers = {
		views[ \peers ].do({ |vws, i|
			var peer;
			peer = evt.knownPeers[i];
				if( peer !? _.active ? false == true ) {
					vws[ \txt ].string = " % (%) % rtt: %ms".format(
						peer.peer.user.name,
						peer.peer.user.id,
						peer.metadata ? "",
						peer.maxRTT !? (_ * 1000).round(0.1) ? "-"
					);
					vws[ \txt ].stringColor = Color.black;
					vws.setRemoveEnabled( false );
				} {
					vws[ \txt ].stringColor = Color.red;
					vws.setRemoveEnabled( true );
				};
		});
	};

	ctrl = SimpleController( evt )
	.put( \connected, {
		{
			views[ \connect ].value = 1;
			views[ \status ].background_( Color.green(0.7) );
		}.defer;
	})
	.put( \disconnected, {
		{
			views[ \connect ].value = 0;
			views[ \status ].background_( Color.red(0.7) );
		}.defer;
	})
	.put( \connecting, {
		{ views[ \status ].background_( Color.yellow(0.9) ); }.defer;
	})
	.put( \knownPeersActive, {
		{ colorPeers.value; }.defer
	})
	.put( \knownPeers, {
		{
			fillPeers.value;
			colorPeers.value;
		}.defer;
	})
	.put( \userName, {
		{
			views[ \userName ].string = evt.userName ? "";
		}.defer;
	});

	fillPeers.value;
	colorPeers.value;

	w.onClose_({ ctrl.remove });

	evt.win = w;
	evt.views = views;
};
);

);