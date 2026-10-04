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
//   hide_from_taskbar(hwnd) no taskbar button for that window
//   single_instance(name)   false if another copy is already running
//   set_launch_at_startup / is_launch_at_startup   HKCU Run entry
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
	bool hide_from_taskbar(int64_t hwnd);
	bool single_instance(const String &name);
	bool set_launch_at_startup(bool enabled, const String &exe_path, const String &args);
	bool is_launch_at_startup() const;

	~CritterNative();
};

} // namespace godot
