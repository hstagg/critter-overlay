// Critter Overlay's Windows layer: the few things Godot cannot do itself.
//
//   idle_ms()               time since any input (GetLastInputInfo)
//   real_input_age_ms()     time since input from a real device. Software
//                           that fakes input (mouse jigglers, auto-clickers)
//                           arrives through Raw Input with no device, so it
//                           does not count. Only counts are kept, never keys.
//   injected_events()       how many faked events have been seen
//   injected_keys()         of which faked key presses
//   poll_hotkey()           1 once per press of the global pause shortcut
//   poll_hotkey_slot(n)     the same for shortcut n (0 pause, 1 spawn)
//   set_hotkey(n, mods, vk) (re)register shortcut n; vk 0 clears it
//   hotkey_state(n)         1 registered, -1 refused (another app has it), 0 none
//   hide_from_taskbar(hwnd) no taskbar button for that window
//   show_in_taskbar(hwnd)   a taskbar button for an owned window (Settings)
//   single_instance(name)   false if another copy is already running
//   set_launch_at_startup / is_launch_at_startup   HKCU Run entry
//   user_busy()             true while a full-screen app, game or
//                           presentation has the screen (Windows' own
//                           "do not disturb" test, SHQueryUserNotificationState)
//
// A background thread owns a message-only window that receives the hotkey
// and Raw Input. No hooks: nothing runs on, or sits in, anyone's input.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class CritterNative : public RefCounted {
	GDCLASS(CritterNative, RefCounted)

protected:
	static void _bind_methods();

public:
	bool start(int hotkey_mods, int hotkey_vk);
	void stop();
	int64_t idle_ms() const;
	int64_t real_input_age_ms() const;
	int64_t injected_events() const;
	int64_t injected_keys() const;
	int poll_hotkey();
	int poll_hotkey_slot(int slot);
	bool set_hotkey(int slot, int mods, int vk);
	int hotkey_state(int slot) const;
	bool hide_from_taskbar(int64_t hwnd);
	bool show_in_taskbar(int64_t hwnd);
	bool single_instance(const String &name);
	bool set_launch_at_startup(bool enabled, const String &exe_path, const String &args);
	bool is_launch_at_startup() const;
	String startup_command() const;
	bool set_startup_command(const String &command);
	bool user_busy() const;

	~CritterNative();
};

} // namespace godot
