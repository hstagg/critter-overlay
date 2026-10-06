extends SceneTree
## Checks the native layer (native/, CritterNative). Needs the DLL built.
## Run: godot --headless --path godot --script res://native_test.gd
## It sends two faked mouse moves, one pixel and back, to check that faked
## input is told apart from real input.

var fails := 0
var checks := 0


func ps(script: String) -> void:
	# Encoded, so Windows' command-line parsing cannot strip its quotes.
	OS.execute("powershell.exe", ["-NoProfile", "-EncodedCommand", Marshalls.raw_to_base64(script.to_utf16_buffer())])


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	if not ClassDB.class_exists("CritterNative"):
		print("NATIVE TEST: CritterNative not loaded (build native/ first) -> FAIL")
		quit(1)
		return
	var n = ClassDB.instantiate("CritterNative")
	check(n.idle_ms() >= 0, "idle_ms works (%d)" % n.idle_ms())
	check(n.real_input_age_ms() == -1, "real input age is -1 before start")
	check(n.start(0, 0), "input thread starts")
	OS.delay_msec(300)
	check(n.real_input_age_ms() >= 0, "real input age readable after start (%d)" % n.real_input_age_ms())

	# A faked mouse event: counted as injected, not as real input.
	var before: int = n.injected_events()
	var age_before: int = n.real_input_age_ms()
	ps("Add-Type -Name M -Namespace W -MemberDefinition '[DllImport(\"user32.dll\")] public static extern void mouse_event(uint f, int x, int y, uint d, System.UIntPtr e);'; [W.M]::mouse_event(1, 1, 0, 0, [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 30; [W.M]::mouse_event(1, -1, 0, 0, [System.UIntPtr]::Zero)")
	OS.delay_msec(400)
	check(n.injected_events() > before, "a faked mouse event is counted as injected (%d -> %d)" % [before, n.injected_events()])
	# Whether the real-input clock moved depends on the user touching the
	# mouse meanwhile, so it is reported, not asserted.
	print("real input age %d -> %d ms (should only drop if someone touched a real device)" % [age_before, n.real_input_age_ms()])

	# A faked F24 key (no app uses it): should arrive with no device.
	var keys_before: int = n.injected_keys()
	ps("Add-Type -Name K -Namespace W -MemberDefinition '[DllImport(\"user32.dll\")] public static extern void keybd_event(byte v, byte s, uint f, System.UIntPtr e);'; [W.K]::keybd_event(0x87, 0, 0, [System.UIntPtr]::Zero); [W.K]::keybd_event(0x87, 0, 2, [System.UIntPtr]::Zero)")
	OS.delay_msec(400)
	print("faked F24: injected keys %d -> %d (2 expected if faked keys arrive with no device)" % [keys_before, n.injected_keys()])

	check(n.poll_hotkey() == 0, "no hotkey press reported without one")
	check(typeof(n.user_busy()) == TYPE_BOOL, "user_busy answers")
	check(n.set_hotkey(1, 0x0001 | 0x0002, 0x87), "spawn shortcut (Ctrl+Alt+F24) sent to the input thread")
	OS.delay_msec(200)
	check(n.hotkey_state(1) == 1, "spawn shortcut registered (state %d)" % n.hotkey_state(1))
	check(n.poll_hotkey_slot(1) == 0, "no spawn press reported without one")
	n.set_hotkey(1, 0, 0)
	OS.delay_msec(200)
	check(n.hotkey_state(1) == 0, "spawn shortcut cleared")
	print("user_busy: %s (true only while a full-screen app or presentation has the screen)" % n.user_busy())
	check(n.single_instance("CritterOverlay.native_test"), "first instance takes the lock")

	# Startup entry: round trip, then put back exactly what was there (on a
	# machine with v2.0 installed, its real entry has this name).
	var run_before: String = n.startup_command()
	check(n.set_launch_at_startup(true, "C:/Temp/critter test.exe", "--x"), "startup entry written")
	check(n.is_launch_at_startup() and "critter test.exe" in n.startup_command(), "startup entry reads back")
	check(n.set_launch_at_startup(false, "", ""), "startup entry removed")
	check(not n.is_launch_at_startup(), "startup entry gone")
	check(n.set_startup_command(run_before) and n.startup_command() == run_before, "the entry that was there is put back")

	check(not n.hide_from_taskbar(0), "hide_from_taskbar refuses a bad handle")
	n.stop()
	check(n.real_input_age_ms() == -1, "stop() ends the thread")
	print("NATIVE TEST: %d checks, %d fails -> %s" % [checks, fails, "PASS" if fails == 0 else "FAIL"])
	quit(0 if fails == 0 else 1)
