## Windows native code replaced by FFM (Java 22+)
The JNI/DLL bridge to Kernel32 (WinConsoleNative) wraps 7 functions: GetStdHandle, GetConsoleMode, SetConsoleMode, GetConsoleOutputCP, GetConsoleScreenBufferInfo, ReadConsoleInputW, WriteConsoleW. All can be replaced with pure Java using `java.lang.foreign` (FFM API, JEP 454). The public API surface stays identical — callers like WinSysTerminal and AbstractWindowsTerminal need zero changes. JLine 3.24+ validates this approach (they added FFM as a terminal provider).
Observed: 2026-04-17

## TestBase is in terminal-api test-jar, available to all modules
TestBase (org.aesh.terminal.TestBase) in terminal-api/src/test/java is published as a test-jar artifact. Modules like terminal-ssh depend on it via `<type>test-jar</type>`. It provides async test infrastructure (latches, await, testComplete) and key constant arrays, but no network/port utility methods. It is the natural home for any shared test utilities needed across modules.
Observed: 2026-04-18

## Parser.stripAwayAnsiCodes exists for ANSI stripping
Parser.stripAwayAnsiCodes(String) in terminal-api uses a compiled regex pattern that handles CSI sequences (\e[...X) and OSC sequences (\e]...\a or \e]...\e\\). Any test needing to strip ANSI codes should use this method rather than hand-rolling a regex. The terminal-ssh module already has terminal-api on its compile classpath.
Observed: 2026-04-18

## WinConsoleNative MRJAR: constants are duplicated by design
The JNI version (src/main/java) and FFM version (src/main/java22) of WinConsoleNative intentionally duplicate all public constants (STD_INPUT_HANDLE, STD_OUTPUT_HANDLE, etc.) because MRJAR requires each version to be a complete, self-contained class file. There is no shared constant file mechanism in MRJAR.
Observed: 2026-04-18

## INPUT_RECORD struct layout for FFM
INPUT_RECORD is 20 bytes with 4-byte alignment. EventType at offset 0 (SHORT + 2 padding). KEY_EVENT_RECORD union starts at offset 4: bKeyDown(INT,4), wRepeatCount(SHORT,8), wVirtualKeyCode(SHORT,10), wVirtualScanCode(SHORT,12), UnicodeChar(SHORT,14), dwControlKeyState(INT,16). WINDOW_BUFFER_SIZE_RECORD: X(SHORT,4), Y(SHORT,6). CONSOLE_SCREEN_BUFFER_INFO is 22 bytes, 2-byte aligned; srWindow starts at offset 10 (Left,Top,Right,Bottom as SHORTs).
Observed: 2026-04-17

## Runtime requirement for FFM
FFM requires `--enable-native-access=ALL-UNNAMED` at runtime (warning in Java 22-23, error in Java 24+). Must be set in maven-surefire-plugin argLine for tests.
Observed: 2026-04-17

## readConsoleKeyEvent is dead code
readConsoleKeyEvent() exists in both the JNI and FFM WinConsoleNative but has zero callers. WinSysTerminal.readConsoleInput() exclusively calls readConsoleInputEvent() which handles both key and window-resize events. readConsoleKeyEvent is a strict subset — it only returns key events and discards everything else. It was likely the original API before readConsoleInputEvent was added to support SIGWINCH.
Observed: 2026-04-18

## VIRTUAL_TERMINAL_PROCESSING constant is duplicated
WinSysTerminal defines its own `VIRTUAL_TERMINAL_PROCESSING = 0x0004` while WinConsoleNative defines `ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004`. Same value, two constants. WinSysTerminal uses its own copy at line 207.
Observed: 2026-04-18
