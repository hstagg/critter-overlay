extends Node
## Is the user at the computer? Drives the focus layer: kittens gather while
## you work, nap when you step away, and wake when you come back.
##
## On Windows the idle time comes from GetLastInputInfo, which sees keyboard
## and mouse input anywhere on the desktop. Godot cannot call user32 itself,
## so a hidden PowerShell child process polls it once a second and streams the
## milliseconds on stdout; a reader thread keeps the latest value. Elsewhere,
## or if that process fails, idle time falls back to how long the mouse has
## been still (keyboard-only typing then reads as idle, so it is a fallback).
##
## With the native layer (native/, CritterNative) there is no PowerShell:
## idle time is time since input from a real device, so software that fakes
## input (mouse jigglers, auto-clickers) neither keeps the critters awake nor
## earns berries. main.gd sets `native` before start().
##
## `--idle-sim=PRESENT,AWAY` replaces both with a fixed cycle, for testing.

signal went_away
signal came_back

const POLL_SCRIPT := """
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class CritterIdle {
	[StructLayout(LayoutKind.Sequential)] struct LII { public uint cbSize; public uint dwTime; }
	[DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LII p);
	public static uint Ms() {
		var l = new LII(); l.cbSize = (uint)Marshal.SizeOf(l);
		GetLastInputInfo(ref l);
		return (uint)Environment.TickCount - l.dwTime;
	}
}
'@
while ($true) { [Console]::Out.WriteLine([CritterIdle]::Ms()); [Console]::Out.Flush(); Start-Sleep -Milliseconds 1000 }
"""

var away_after := 180.0        # seconds idle before the kittens settle down
var idle_s := 0.0
var away := false
var source := "mouse"

var sim := PackedFloat32Array()   # [present_s, away_s], or empty
var _sim_t := 0.0

var _last_mouse := Vector2i(-99999, -99999)
var _mouse_idle := 0.0

var _ps_pid := -1
var _ps_stdio: FileAccess
var _ps_thread: Thread
var _ps_mutex := Mutex.new()
var _ps_ms := -1
var _ps_at := 0
var _running := true
var native: RefCounted = null    # CritterNative, when built


func start() -> void:
	if native != null and native.real_input_age_ms() >= 0:
		return
	if sim.is_empty() and OS.get_name() == "Windows":
		_start_poller()


func _start_poller() -> void:
	var encoded := Marshalls.raw_to_base64(POLL_SCRIPT.to_utf16_buffer())
	var r := OS.execute_with_pipe("powershell.exe",
		["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", encoded])
	if r.is_empty():
		push_warning("presence: could not start the idle poller; using mouse movement")
		return
	_ps_stdio = r["stdio"]
	_ps_pid = r["pid"]
	_ps_thread = Thread.new()
	_ps_thread.start(_read_poller)


func _read_poller() -> void:
	while _running:
		var line := _ps_stdio.get_line().strip_edges()
		if line.is_valid_int():
			_ps_mutex.lock()
			_ps_ms = line.to_int()
			_ps_at = Time.get_ticks_msec()
			_ps_mutex.unlock()
		elif _ps_stdio.get_error() != OK:
			break


func _process(delta: float) -> void:
	var m := DisplayServer.mouse_get_position()
	if m != _last_mouse:
		_last_mouse = m
		_mouse_idle = 0.0
	else:
		_mouse_idle += delta

	if not sim.is_empty():
		_sim_t = fmod(_sim_t + delta, sim[0] + sim[1])
		idle_s = 0.0 if _sim_t < sim[0] else away_after + (_sim_t - sim[0])
		source = "sim"
	elif native != null and native.real_input_age_ms() >= 0:
		idle_s = native.real_input_age_ms() / 1000.0
		source = "native"
	else:
		idle_s = _mouse_idle
		source = "mouse"
		_ps_mutex.lock()
		var fresh := _ps_ms >= 0 and Time.get_ticks_msec() - _ps_at < 5000
		var ps_idle := _ps_ms / 1000.0
		_ps_mutex.unlock()
		if fresh:
			idle_s = ps_idle
			source = "windows"

	if not away and idle_s >= away_after:
		away = true
		went_away.emit()
	elif away and idle_s < 2.0:
		away = false
		came_back.emit()


func sleep_bias() -> float:
	# 0 while active, rising towards 1 as idle time nears the away threshold.
	if away:
		return 1.0
	return clampf(idle_s / away_after, 0.0, 1.0) * 0.6


func _exit_tree() -> void:
	stop()


func stop() -> void:
	# Kill the poller and join its reader. Safe to call twice.
	_running = false
	if _ps_pid > 0:
		OS.kill(_ps_pid)
		_ps_pid = -1
	if _ps_thread != null and _ps_thread.is_started():
		_ps_thread.wait_to_finish()
