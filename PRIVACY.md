# Privacy

StepAside performs its work locally on the Mac. It contains no analytics SDK, advertising SDK, crash uploader, update network client, or other network client.

## Permission

StepAside requests macOS Accessibility permission solely to read the geometry and state of ordinary application windows and to move or resize eligible windows after an explicit Arrange or Undo action.

It does not request Screen Recording, Input Monitoring, Full Disk Access, Contacts, Calendar, Camera, or Microphone access. The global shortcut uses the public Carbon hot-key registration API and does not log keystrokes.

## Data stored on the Mac

The app stores only these preferences in `UserDefaults`:

- `spacing`
- `hotKeyKeyCode`
- `hotKeyModifiers`
- `completedOnboarding`
- `latestResult`

The latest result is generic copy such as `6 windows · arranged`; it does not contain window titles.

The most recent pre-arrangement window frames are held only in memory to support Undo and are discarded when StepAside quits. Window titles may be used transiently to match public Core Graphics and Accessibility records, but titles are never persisted or logged by release builds.

## Data not collected

StepAside does not capture pixels, read visible messages or document text, inspect passwords, read the clipboard, maintain browsing history, fingerprint applications, or transmit any information off the device.

