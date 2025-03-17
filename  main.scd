(
~organ_sync = ~organ_sync ? ();

~organ_sync.filePath = thisProcess.nowExecutingPath.dirname;

[
	"aoo"
].do({ |item|
	(~organ_sync.filePath +/+ item ++ ".scd").load;
});


~organ_sync.aoo= ().parent_( ~aoo );
~organ_sync.aoo.userName = ""; // -> fill in for auto-connect
~organ_sync.aoo.connect;
~organ_sync.aoo.makeWindow;

~organ_sync.aoo.addOSCFunc({ |msg|
	~test_routine.stop;
	if( msg[1] > 0 ) {
		~test_routine = {
			inf.do { |i|
				~organ_sync.aoo.sendMsg( nil, 0.0, [ '/test', i % 1024 ]);
				msg[1].wait;
			};
		}.fork;
	};
}, '/test_routine' );

~organ_sync.aoo.addOSCFunc({ |msg|
	msg.postcs;
}, '/post' );

~organ_sync.aoo.addOSCFunc({ |msg|
	~organ_sync.aoo.knownPeers.do({ |item|
		~organ_sync.aoo.sendMsg( nil, 0.0, [ '/post', "lates", item.lates ? 0 ] );
	});
}, '/request_lates' );

)

/*
~organ_sync.aoo.sendMsg( "Pi", nil, [ '/test_routine', 0.01 ] );
~organ_sync.aoo.sendMsg( "Pi", nil, [ '/test_routine', 0 ] );

~organ_sync.aoo.sendMsg( "Pi", nil, [ '/request_lates' ])
*/