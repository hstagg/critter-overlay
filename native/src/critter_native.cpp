#include "critter_native.h"

#include <godot_cpp/core/class_db.hpp>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#endif

#include <atomic>
#include <string>
#include <thread>

using namespace godot;

namespace {

// One input thread per process, shared by every CritterNative instance.
std::atomic<bool> g_running{ false };
std::atomic<int64_t> g_last_real_tick{ 0 };   // GetTickCount64 of the last real-device input
std::atomic<int64_t> g_injected{ 0 };
std::atomic<int64_t> g_injected_keys{ 0 };
std::atomic<int> g_hotkey_presses{ 0 };
std::thread g_thread;
#ifdef _WIN32
std::atomic<DWORD> g_thread_id{ 0 };
HANDLE g_instance_mutex = nullptr;
const wchar_t *RUN_KEY = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const wchar_t *RUN_VALUE = L"Critter Overlay";
const int HOTKEY_ID = 0xC0DE;

LRESULT CALLBACK input_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
	if (msg == WM_INPUT) {
		// Raw Input: no hooks, and only the header is read (which device,
		// mouse or keyboard), never the key or the movement. Input faked by
		// software (SendInput, mouse_event, keybd_event) has no device.
		RAWINPUTHEADER head;
		UINT size = sizeof(head);
		if (GetRawInputData((HRAWINPUT)lp, RID_HEADER, &head, &size, sizeof(RAWINPUTHEADER)) == sizeof(head)) {
			if (head.hDevice == nullptr) {
				if (head.dwType == RIM_TYPEKEYBOARD) {
					g_injected_keys.fetch_add(1);
				} else {
					g_injected.fetch_add(1);
				}
			} else {
				g_last_real_tick.store((int64_t)GetTickCount64());
			}
		}
		return DefWindowProcW(hwnd, msg, wp, lp);
	}
	if (msg == WM_HOTKEY && wp == HOTKEY_ID) {
		g_hotkey_presses.fetch_add(1);
		return 0;
	}
	return DefWindowProcW(hwnd, msg, wp, lp);
}

void input_thread(int mods, int vk) {
	g_thread_id.store(GetCurrentThreadId());
	WNDCLASSW wc = {};
	wc.lpfnWndProc = input_proc;
	wc.hInstance = GetModuleHandleW(nullptr);
	wc.lpszClassName = L"CritterOverlayInput";
	RegisterClassW(&wc);
	HWND hwnd = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
	if (!hwnd) {
		g_running.store(false);
		return;
	}
	// Mouse and keyboard, delivered even when another app has focus.
	// RIDEV_INPUTSINK reads events, it does not intercept them.
	RAWINPUTDEVICE devs[2] = {};
	devs[0].usUsagePage = 0x01;
	devs[0].usUsage = 0x02;   // mouse
	devs[0].dwFlags = RIDEV_INPUTSINK;
	devs[0].hwndTarget = hwnd;
	devs[1].usUsagePage = 0x01;
	devs[1].usUsage = 0x06;   // keyboard
	devs[1].dwFlags = RIDEV_INPUTSINK;
	devs[1].hwndTarget = hwnd;
	RegisterRawInputDevices(devs, 2, sizeof(RAWINPUTDEVICE));
	if (vk != 0) {
		RegisterHotKey(hwnd, HOTKEY_ID, (UINT)mods | MOD_NOREPEAT, (UINT)vk);
	}
	g_last_real_tick.store((int64_t)GetTickCount64());

	MSG msg;
	while (g_running.load() && GetMessageW(&msg, nullptr, 0, 0) > 0) {
		TranslateMessage(&msg);
		DispatchMessageW(&msg);
	}
	if (vk != 0) {
		UnregisterHotKey(hwnd, HOTKEY_ID);
	}
	devs[0].dwFlags = RIDEV_REMOVE;
	devs[0].hwndTarget = nullptr;
	devs[1].dwFlags = RIDEV_REMOVE;
	devs[1].hwndTarget = nullptr;
	RegisterRawInputDevices(devs, 2, sizeof(RAWINPUTDEVICE));
	DestroyWindow(hwnd);
	UnregisterClassW(wc.lpszClassName, wc.hInstance);
}
#endif

} // namespace

bool CritterNative::start(int hotkey_mods, int hotkey_vk) {
#ifdef _WIN32
	if (g_running.load()) {
		return true;
	}
	g_running.store(true);
	g_thread = std::thread(input_thread, hotkey_mods, hotkey_vk);
	return true;
#else
	return false;
#endif
}

void CritterNative::stop() {
#ifdef _WIN32
	if (!g_running.exchange(false)) {
		return;
	}
	DWORD id = g_thread_id.load();
	if (id != 0) {
		PostThreadMessageW(id, WM_QUIT, 0, 0);
	}
	if (g_thread.joinable()) {
		g_thread.join();
	}
	g_thread_id.store(0);
#endif
}

CritterNative::~CritterNative() {
	// The thread is process-wide; it stops with stop() or at process exit.
}

int64_t CritterNative::idle_ms() const {
#ifdef _WIN32
	LASTINPUTINFO lii = {};
	lii.cbSize = sizeof(lii);
	if (!GetLastInputInfo(&lii)) {
		return -1;
	}
	return (int64_t)(GetTickCount() - lii.dwTime);
#else
	return -1;
#endif
}

int64_t CritterNative::real_input_age_ms() const {
#ifdef _WIN32
	if (!g_running.load()) {
		return -1;
	}
	return (int64_t)GetTickCount64() - g_last_real_tick.load();
#else
	return -1;
#endif
}

int64_t CritterNative::injected_events() const {
	return g_injected.load() + g_injected_keys.load();
}

int64_t CritterNative::injected_keys() const {
	return g_injected_keys.load();
}

int CritterNative::poll_hotkey() {
	return g_hotkey_presses.exchange(0) > 0 ? 1 : 0;
}

bool CritterNative::hide_from_taskbar(int64_t hwnd_value) {
#ifdef _WIN32
	HWND hwnd = (HWND)(intptr_t)hwnd_value;
	if (!IsWindow(hwnd)) {
		return false;
	}
	LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
	ex = (ex & ~WS_EX_APPWINDOW) | WS_EX_TOOLWINDOW;
	// The taskbar only notices a style change across a hide and show.
	bool visible = IsWindowVisible(hwnd) != 0;
	if (visible) {
		ShowWindow(hwnd, SW_HIDE);
	}
	SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex);
	if (visible) {
		ShowWindow(hwnd, SW_SHOWNOACTIVATE);
	}
	return true;
#else
	return false;
#endif
}

bool CritterNative::single_instance(const String &name) {
#ifdef _WIN32
	if (g_instance_mutex != nullptr) {
		return true;
	}
	std::wstring wname((const wchar_t *)name.wide_string().get_data());
	g_instance_mutex = CreateMutexW(nullptr, FALSE, wname.c_str());
	if (g_instance_mutex != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
		CloseHandle(g_instance_mutex);
		g_instance_mutex = nullptr;
		return false;
	}
	return true;
#else
	return true;
#endif
}

bool CritterNative::set_launch_at_startup(bool enabled, const String &exe_path, const String &args) {
#ifdef _WIN32
	HKEY key;
	if (RegOpenKeyExW(HKEY_CURRENT_USER, RUN_KEY, 0, KEY_SET_VALUE, &key) != ERROR_SUCCESS) {
		return false;
	}
	LSTATUS st;
	if (enabled) {
		String cmd = "\"" + exe_path.replace("/", "\\") + "\"" + (args.is_empty() ? String() : " " + args);
		std::wstring w((const wchar_t *)cmd.wide_string().get_data());
		st = RegSetValueExW(key, RUN_VALUE, 0, REG_SZ, (const BYTE *)w.c_str(), (DWORD)((w.size() + 1) * sizeof(wchar_t)));
	} else {
		st = RegDeleteValueW(key, RUN_VALUE);
		if (st == ERROR_FILE_NOT_FOUND) {
			st = ERROR_SUCCESS;
		}
	}
	RegCloseKey(key);
	return st == ERROR_SUCCESS;
#else
	return false;
#endif
}

bool CritterNative::is_launch_at_startup() const {
#ifdef _WIN32
	HKEY key;
	if (RegOpenKeyExW(HKEY_CURRENT_USER, RUN_KEY, 0, KEY_QUERY_VALUE, &key) != ERROR_SUCCESS) {
		return false;
	}
	LSTATUS st = RegQueryValueExW(key, RUN_VALUE, nullptr, nullptr, nullptr, nullptr);
	RegCloseKey(key);
	return st == ERROR_SUCCESS;
#else
	return false;
#endif
}

bool CritterNative::user_busy() const {
#ifdef _WIN32
	QUERY_USER_NOTIFICATION_STATE state;
	if (FAILED(SHQueryUserNotificationState(&state))) {
		return false;
	}
	return state == QUNS_BUSY || state == QUNS_RUNNING_D3D_FULL_SCREEN || state == QUNS_PRESENTATION_MODE;
#else
	return false;
#endif
}

void CritterNative::_bind_methods() {
	ClassDB::bind_method(D_METHOD("start", "hotkey_mods", "hotkey_vk"), &CritterNative::start);
	ClassDB::bind_method(D_METHOD("stop"), &CritterNative::stop);
	ClassDB::bind_method(D_METHOD("idle_ms"), &CritterNative::idle_ms);
	ClassDB::bind_method(D_METHOD("real_input_age_ms"), &CritterNative::real_input_age_ms);
	ClassDB::bind_method(D_METHOD("injected_events"), &CritterNative::injected_events);
	ClassDB::bind_method(D_METHOD("injected_keys"), &CritterNative::injected_keys);
	ClassDB::bind_method(D_METHOD("poll_hotkey"), &CritterNative::poll_hotkey);
	ClassDB::bind_method(D_METHOD("hide_from_taskbar", "hwnd"), &CritterNative::hide_from_taskbar);
	ClassDB::bind_method(D_METHOD("single_instance", "name"), &CritterNative::single_instance);
	ClassDB::bind_method(D_METHOD("set_launch_at_startup", "enabled", "exe_path", "args"), &CritterNative::set_launch_at_startup);
	ClassDB::bind_method(D_METHOD("is_launch_at_startup"), &CritterNative::is_launch_at_startup);
	ClassDB::bind_method(D_METHOD("user_busy"), &CritterNative::user_busy);
}
