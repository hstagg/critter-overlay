# Native layer (CritterNative)

A small GDExtension for the Windows calls Godot cannot make: idle time from
real devices only (faked input from jigglers is recognised through Raw Input,
with no hooks), the global pause shortcut, no taskbar button for the hidden
main window, single instance, and the launch-at-startup entry. The game runs
without it, falling back to a PowerShell idle poller.

Build (Windows, Visual Studio Build Tools 2022 with the C++ workload, Python
with `pip install scons`, and godot-cpp cloned beside this repo at the pinned
tag):

    git clone --branch 10.0.0-stable https://github.com/godotengine/godot-cpp ..\godot-cpp
    cd native
    godot --headless --dump-extension-api
    python -m SCons custom_api_file=extension_api.json target=template_debug
    python -m SCons custom_api_file=extension_api.json target=template_release

godot-cpp is pinned to **10.0.0-stable** (commit 507ed9d), the version the
shipped DLL is built from. Moving to another version is a dependency change:
discuss it first. `extension_api.json` comes from the Godot that runs the game
(4.7.2), so it is not committed. godot-cpp links the C++ runtime statically
(`use_static_cpp`, its default on Windows), so players need no Visual C++
redistributable. Check a new DLL with `dumpbin /dependents`: it should list
only USER32, ADVAPI32, SHELL32 and KERNEL32.

The DLL lands in `godot/bin/`. Godot only loads it once the project has been
imported (`godot --headless --path godot --import`), which writes
`.godot/extension_list.cfg`. Then check it with
`godot --headless --path godot --script res://native_test.gd`.
