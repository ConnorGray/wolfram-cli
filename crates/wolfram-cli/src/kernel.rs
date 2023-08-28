use wolfram_app_discovery::WolframApp;
use wolfram_client::WolframSession;

use crate::config;

const WOLFRAM_MINIMUM_VERSION: (u32, u32) = (13, 1);

pub fn launch_kernel() -> WolframSession {
	let app = get_wolfram_app();

	let exe = app.kernel_executable_path().unwrap();

	let mut session = WolframSession::launch_kernel(&exe)
		.expect("unable to launch WolframKernel");

	if config::verbosity() >= 2 {
		eprintln!(
			"verbose: WolframKernel WSTP link name: {:?}",
			session.process().link().link_name()
		);
	}

	session
}

/// Find a suitable Wolfram Language installation
fn get_wolfram_app() -> WolframApp {
	let app = WolframApp::try_default()
		.expect("unable to find any Wolfram Language installations");

	if config::verbosity() >= 1 {
		eprintln!(
			"verbose: Using Wolfram installation at: {}",
			app.installation_directory().display()
		);
	}

	let wolfram_version = app.wolfram_version().unwrap();

	if wolfram_version.major() < WOLFRAM_MINIMUM_VERSION.0
		|| (wolfram_version.major() == WOLFRAM_MINIMUM_VERSION.0
			&& wolfram_version.minor() < WOLFRAM_MINIMUM_VERSION.1)
	{
		panic!(
            "incompatible Wolfram version: {wolfram_version}. {}.{} or newer is required for this command.",
            WOLFRAM_MINIMUM_VERSION.0, WOLFRAM_MINIMUM_VERSION.1
        )
	}

	app
}
