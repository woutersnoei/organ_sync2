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
)