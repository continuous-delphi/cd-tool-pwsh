# Add-ToSystemPath

## Synopsis

Adds a directory to the system PATH if it is not already present.

## Description

`Add-ToSystemPath` adds a single directory to the machine-level `PATH`
environment variable after normalizing the supplied path and checking
whether it already exists.

The command is intended for administrative setup and developer
environment bootstrapping. It avoids duplicate entries, validates that
the supplied path exists, warns if the resulting PATH becomes unusually
large, and refreshes the current PowerShell session PATH so the change
is immediately available in the current shell.

Typical scenarios include:

- developer workstation setup
- module or tool bootstrap scripts
- CI runner provisioning
- local machine environment configuration

The command is designed to behave like a native PowerShell command.

------------------------------------------------------------------------

## Syntax

``` powershell
Add-ToSystemPath [-PathToAdd] <string>
```

------------------------------------------------------------------------

## Parameters

### PathToAdd

Directory path to add to the system PATH.

The path must already exist and must refer to a directory.

Example:

``` powershell
-PathToAdd C:\Tools\MyApp
```

------------------------------------------------------------------------

## Behavior

`Add-ToSystemPath` performs the following steps:

- verifies the current session is running with administrator privileges
- confirms the target directory exists
- normalizes the directory path to a full filesystem path
- compares the normalized path against existing machine PATH entries
- skips insertion if the path already exists
- updates the machine PATH if the path is not present
- refreshes the current PowerShell session PATH using machine and user PATH values

If the updated PATH becomes very large, the command emits a warning.

------------------------------------------------------------------------

## Output

This command is primarily host-output oriented.

When a new path is added, the command writes confirmation messages to the
console.

When the path already exists, the command writes an informational message
indicating that no change was needed.

Example success output:

``` text
Added to system PATH:
  C:\Tools\MyApp

The machine PATH has been updated.
The current PowerShell session PATH has also been refreshed.

New processes will see the updated PATH immediately.
Some already-running applications may need to be restarted.
```

Example already-present output:

``` text
Path already exists in the system PATH:
  C:\Tools\MyApp
```

------------------------------------------------------------------------

## Examples

### Add a tools directory to the system PATH

``` powershell
Add-ToSystemPath -PathToAdd C:\Tools\MyApp
```

### Add a directory using positional syntax

``` powershell
Add-ToSystemPath C:\Tools\MyApp
```

### Example with explicit module import

``` powershell
Import-Module ContinuousDelphi.Tools
Add-ToSystemPath C:\Tools\MyApp
```

### Example failure when not elevated

``` powershell
Add-ToSystemPath C:\Tools\MyApp
```

If the current PowerShell session is not running as Administrator, the
command throws an error indicating that elevation is required.
