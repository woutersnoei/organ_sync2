(
~organ_sync.makeInstallWin = { |evt|
	var osxJob = 86474, pipeline = 16088;

	evt.installWin = Window().front;
	evt.installWin.addFlowLayout;

	evt.installTxt = StaticText( evt.installWin, 392 @ 20 )
	.string_( "Required library Aoo is not installed" );

	Platform.case(
		\osx, {
			Button( evt.installWin, 392 @ 40 )
			.states_([[ "download and install" ]])
			.action_({ |bt|
				bt.states_([[ "downloading.." ]]);
				bt.action = nil;
				"curl -o ~/Downloads/aoo_develop_macOS_package.zip https://git.iem.at/aoo/aoo/-/jobs/%/artifacts/download?file_type=archive && ditto -xk ~/Downloads/aoo_develop_macOS_package.zip ~/Downloads/aoo_develop_macOS_package/ && ditto ~/Downloads/aoo_develop_macOS_package/sc/sc/aoo %/Extensions/aoo && xattr -rd com.apple.quarantine %/Extensions/aoo && rm -rf ~/Downloads/aoo_develop_macOS_package.zip && rm -rf ~/Downloads/aoo_develop_macOS_package/ && echo 'installed aoo'".format(
					osxJob, Platform.userAppSupportDir.escapeChar( $ ), Platform.userAppSupportDir.escapeChar( $ )
				).unixCmd({
					{
						evt.installTxt.string = "Aoo installed, recompile SuperCollider to enable";
						bt.states_([[ "recompile", Color.black, Color.green ]]);
						bt.action_({ thisProcess.recompile });
					}.defer;
				});
			})
		},
		{
			StaticText( evt.installWin, 392 @ 20 )
			.string_( "To install, select appropriate package here:" );
			Button( evt.installWin, 392 @ 20 )
			.states_( [[ "https://git.iem.at/aoo/aoo/-/pipelines/%/".format( pipeline ) ]] )
			.action_({ "https://git.iem.at/aoo/aoo/-/pipelines/%/".format( pipeline ).openOS });
			StaticText( evt.installWin, 392 @ 20 )
			.string_( "Install the folder sc/sc/aoo here:" );
			Button( evt.installWin, 392 @ 20 )
			.states_( [[ "%/Extensions".format( Platform.userAppSupportDir ) ]] )
			.action_({ "%/Extensions".format( Platform.userAppSupportDir ).openOS });
			StaticText( evt.installWin, 392 @ 20 )
			.string_( "And then recompile SuperCollider" );
			Button(  evt.installWin, 392 @ 20 )
			.states_( [[ "recompile" ]] )
			.action_({ thisProcess.recompile });
		}
	);
};

if( 'AooClient'.asClass.isNil ) {  ~organ_sync.makeInstallWin; false; } { true };
)