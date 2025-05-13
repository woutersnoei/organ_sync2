(
// boot server first!

~aoo = ~aoo ? ();

~aoo.groupName = "ws-test";

~aoo.userName = nil; // <- change this to yours locally

~aoo.server = "aoo.iem.at";

~aoo.port = 9995;

~aoo.reliable = false; // message sending mode, false is probably ok

~aoo.verbose = true;

~aoo.formatMetaDataFunc = { |md| (md ? "").asString };

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
							} {
								evt.changed( \disconnected );
							};
						}, userMetadata: AooData( \json, evt.dictToJSON( evt.metadata ? () ) ) );
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
		},
		\peerLeave, {
			evt.updatePeers;
		},
		\peerUpdate, {
			evt.updatePeers;
		},
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
		if( timeOffset < 0 ) {
			knownPeer.lates = (knownPeer.lates ? 0) + 1;
			if( evt.verbose == true ) { "late: %, %, %\n".postf( timeOffset, peer, obj ) };
		};
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
	if( evt.client.notNil && { evt.client.groups.size > 0 }) {
		evt.client.updateUser( evt.groupName,
			AooData( \json, evt.dictToJSON( evt.metadata ? () ))
		);
	};
};

~aoo.addOSCFunc = { |evt, func, key = '/test'|
	var name;
	if( func.notNil ) {
		name = "recv%_%".format( evt.port, key ).asSymbol;
		evt.oscFuncCTRLs = evt.oscFuncCTRLs ?? {()};
		evt.oscFuncCTRLs[ key ].free;
		evt.oscFuncCTRLs[ key ] = SimpleController( evt )
		.put( \connected, {
			"adding OSCdef '%'\n".postf( name );
			OSCdef( name, { |...args| func.value( *args ++ [ evt ] ) }, key, dispatcher: evt.client.dispatcher );
		})
		.put( \disconnected, {
			"removing OSCdef '%'\n".postf( name );
			OSCdef( name ).free;
		});
		if( evt.client.notNil && { evt.client.state == \connected }) {
			evt.oscFuncCTRLs[ key ].update( evt, \connected );
		};
	} {
		evt.removeOSCFunc( key );
	};
};

~aoo.removeOSCFunc = { |evt, key = '/test'|
	var name = "recv%_%".format( evt.port, key ).asSymbol;
	OSCdef( name ).free;
	evt.oscFuncCTRLs !? { |x| x[ key ].remove; x[ key ] = nil };
	"removing OSCdef '%'\n".postf( name );
};

~aoo.sendMsg = { |evt, peer, time, msg|
	var smb;
	if( peer.isString or: { peer.isKindOf( Symbol ) } ) {
		smb = peer.asSymbol;
		peer = evt.client.peers.detect({ |item|
			item.user.name.asSymbol == smb;
		});
		if( peer.isNil ) { "user '%' not found, sent to all instead\n".postf( smb ); }
	};

	time = time ? 0.0;

	evt.client.sendMsg( peer, time, msg, evt.reliable == true );

	if( evt.verbose ) { "sendMsg( %, %, % )\n".postf( peer, time, msg ); };

	if( peer.isNil ) {
		evt.knownPeers.select({ |item| item.active == true }).do({ |item|
			item.sent_( true ).changed( \sent );
		});
	} {
		evt.findKnownPeer( peer ) !? { |item| item.sent_( true ).changed( \sent ); };
	};
};

~aoo.getClientPeer = { |evt, knownPeer|
	evt.client.peers.detect({ |peer| peer.user.name.asSymbol == knownPeer.name })
};

~aoo.updatePeers = { |evt, reset = false|
	var changed = false, activeChanged = false;
	if( reset ) { evt.knownPeers = []; changed = true; };
	evt.client.peers.do({ |peer|
		if( (evt.knownPeers ? []).any({ |knownPeer|
			peer.user.name.asSymbol === knownPeer.name
		}).not ) {
			evt.knownPeers = evt.knownPeers.add( ( name: peer.user.name.asSymbol, id: peer.user.id, active: true ) );
			changed = true;
		};
	});
	evt.knownPeers.do({ |item|
		var clientPeer;
		clientPeer = evt.getClientPeer( item );
		if( clientPeer.notNil ) {
			if( item.name != clientPeer.user.name.asSymbol or: {
				item.id != clientPeer.user.id
			}) {
				item.name = clientPeer.user.name.asSymbol;
				item.id = clientPeer.user.id;
				changed = true;
			};
			if( item.active != true ) {
				item.active = true;
				activeChanged = true;
			};
			item.metadata = if( clientPeer.user.metadata.notNil ) {
				evt.jsonToDict( clientPeer.user.metadata.data )
			} { nil };
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
		a.name <= (b.name)
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
	case { peer.isKindOf( AooPeer ) } {
		peer = peer.user.name;
	} { peer.isKindOf( Integer ) } {
		peer = evt.knownPeers[ peer ] !? _.name ? peer;
	};
	peer = peer.asSymbol;
	evt.knownPeers.detect({ |item|
		item.name == peer;
	});
};

~aoo.resetRTT = { |evt|
	evt.knownPeers.do({ |item|
		item.maxRTT = nil;
	})
};

(
~aoo.makeWindow = { |evt, inView|
	var w, views = (), update, fillPeers, colorPeers, ctrl;
	if( evt.win.notNil && { evt.win.isClosed.not } ) {
		evt.win.close;
	};
	if( inView.notNil ) {
		w = CompositeView( inView, Rect( 0,0, 412, 276 ) )
		.resize_( 5 );
		w.bounds = w.bounds.insetAll( -4, -4, -4, 0 );
	} {
		w = Window( "AOO : %".format( evt.server ), Rect(200,200, 420, 280) ).front;
		w.asView.minWidth_( 420 ).minHeight_( 256 );
	};

	w.addFlowLayout;

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
			evt.connect;
		};
	});

	views[ \status ] = StaticText( w, 100@20 )
	.string_( evt.groupName )
	.align_( \center )
	.background_(
		[
			Color.red(0.7),
			Color.green(0.7)
		][ (evt.client.notNil && { evt.client.groups.size > 0 }).binaryValue ]
	);

	views[ \connect ] = Button( w, 100@20 )
	.states_([[ "connect" ],[ "disconnect" ]])
	.value_( (evt.client.notNil && { evt.client.groups.size > 0 }).binaryValue )
	.action_({ |bt|
		switch( bt.value,
			1, { evt.connect; },
			0, {
				evt.end;
				evt.updatePeers(  );
			}
		);
	});

	views[ \comp ] = CompositeView( w, 412@224 ).background_( Color.gray(0.9) ).resize_(4);
	views[ \comp ].addFlowLayout;

	w.asView.decorator.nextLine;

	views[ \sort ] = Button( w, 100@20 )
	.states_([["sort"]])
	.resize_( 7 )
	.action_({
		evt.sortKnownPeers;
	});

	views[ \remove ] = Button( w, 204@20 )
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
				(item.name.hash % 2048).linlin( 0,2048, 0.0, 1.0 ), 0.1, 0.7 )
			)
			.string_( " % (%)".format( item.name, item.id ) );
			vws[ \send ] = StaticText( vws[ \comp ], Rect( vws[ \comp ].bounds.width - 20, 0, 20, 20 ) )
			.resize_(6)
			.string_( "s" )
			.align_( \center )
			.stringColor_( [ Color.gray(0.75), Color.black ][(item.send ? true).binaryValue] );
			vws[ \receive ] = StaticText( vws[ \comp ], Rect( vws[ \comp ].bounds.width - 40, 0, 20, 20 ) )
			.resize_(6)
			.string_( "r" )
			.align_( \center )
			.stringColor_( [ Color.gray(0.75), Color.black ][(item.receive ? true).binaryValue] );
			menu = Menu(
				MenuAction.separator( " % (%) %".format(
					item.name,
					item.id,
					item.metadata ? ""
				) ),
				MenuAction( "Send", { |act, bool|
					item.send = bool;
					if( bool == true ) {
						vws[ \send ].stringColor = Color.black;
					} {
						vws[ \send ].stringColor = Color.gray( 0.75 );
					};
				})
				.checked_( true ),
				MenuAction( "Receive", { |act, bool|
					item.receive = bool;
					if( bool == true ) {
						vws[ \receive ].stringColor = Color.black;
					} {
						vws[ \receive ].stringColor = Color.gray( 0.75 );
					};
				})
				.checked_( true ),
				MenuAction.separator,
				MenuAction( "Reset lates", { item.lates = nil }),
				MenuAction( "Plot time offsets...", { item.recvOffsets !? _.plot }),
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
				vws[ \txt ].string = " % (%) % rtt: %ms, late: %".format(
					peer.name,
					peer.id,
					evt[ \formatMetaDataFunc ].value( peer.metadata ),
					peer.maxRTT !? (_ * 1000).round(0.1) ? "-",
					peer.lates ? "-"
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