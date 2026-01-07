### Testing

This repo uses a simple headless test runner:
- `tests/run_tests.gd`

It checks:
- face presentation math (faces point toward camera)
- safe positioning above floor
- default “printed label” offsets
- main camera defaults (so framing regressions are caught)

### Run tests (Windows / PowerShell)

You must provide your Godot executable path (Godot is usually not on PATH):

```powershell
& "C:\Users\sargis.khachatryan\Desktop\Godot_v4.5.1-stable_win64.exe" --headless --script "res://tests/run_tests.gd" --verbose
```

Expected output ends with something like:
- `Tests: <N> assertions, 0 failures`

### Logs

Godot file logging is enabled in `project.godot`.

In your environment, the file log ended up at:
- `C:\Users\<you>\AppData\Roaming\Godot\app_userdata\Diceatro\logs\godot.log`

If you want a *single command* to write console output to a file, note that PowerShell redirection may not capture all Godot output in every setup. File logging is the reliable option.

### Optional: a fuller unit test framework

If you later want a more traditional unit test workflow, consider GUT (Godot Unit Test).
Docs: `https://gut.readthedocs.io/en/latest/Command-Line.html`


