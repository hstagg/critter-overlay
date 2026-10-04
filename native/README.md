# Native layer (CritterNative)

A small GDExtension for the Windows calls Godot cannot make: idle time from
real devices only (faked input from jigglers is recognised through Raw Input,
with no hooks), the global pause shortcut, no taskbar button for the hidden
main window, single instance, and the launch-at-startup entry. The game runs
without it, falling back to a PowerShell idle poller.

Build (Windows, Visual Studio Build Tools 2022 with the C++ workload, Python
with `pip install scons`, and godot-cpp cloned beside this repo):

    cd native
    godot --headless --dump-extension-api
    python -m SCons custom_api_file=extension_api.json target=template_debug

The DLL lands in `godot/bin/`. Godot only loads it once the project has been
imported (`godot --headless --path godot --import`), which writes
`.godot/extension_list.cfg`. Then check it with
`godot --headless --path godot --script res://native_test.gd`.
