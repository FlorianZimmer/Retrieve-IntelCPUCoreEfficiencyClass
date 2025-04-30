Intel Hybrid-Core Mapper – PowerShell-only

    Map Task-Manager CPU graphs to P- and E-cores on Windows without installing anything

What is this?

A single PowerShell script that calls the native GetSystemCpuSetInformation API to discover every logical processor’s EfficiencyClass.
That byte is what Windows’ scheduler already uses to decide whether a core is “performance-oriented” (P-core) or “efficiency-oriented” (E-core / LP-E-core).
The script prints a table like:

CPU CoreIndex CoreType EClass
--- --------- -------- ------
 0     0        P         2
 1     0        P         2
 ...  ...      ...       ...
12    10        E         0   # LP-E
13    11        E         0   # LP-E

Use it once, memorize which Task-Manager charts are which cores, and you instantly understand your laptop’s workload distribution.
Why another “which-core” tool?

    100 % native – just stock PowerShell (Add-Type) and the Win32 API.

    No admin, no drivers, no downloads – runs in a locked-down corporate image or fresh Windows install.

    Works on all recent Intel hybrid CPUs – 12th Gen (Alder Lake) through Meteor Lake (Core Ultra), desktop or mobile.

    Consistent output – fixes the common struct-layout bugs that show random values.

Requirements

    Windows 10 21H1 / Windows 11 (the API first exposed EfficiencyClass in 1903).

    PowerShell 5.x or PowerShell 7+.
    (32-bit and 64-bit both fine.)

How it works

    Compiles ~35 lines of C# on-the-fly with Add-Type.

    Calls kernel32!GetSystemCpuSetInformation twice
    (probe for buffer size, then fill).

    Deserialises each SYSTEM_CPU_SET_INFORMATION entry.

    Picks the highest EfficiencyClass byte as the P-core marker (Intel always uses the largest value for the fastest cores).

    Emits a neat table.

Usage

.\Get-HybridCoreMap.ps1          # normal user shell

Optional parameters:

    -Raw  returns the array of structures instead of a table

    -Json outputs structured JSON (handy for logging / dashboards)

Typical output (Core Ultra 7 155U, 2 P + 8 E + 2 LP-E)

PS> .\Get-HybridCoreMap.ps1
CPU CoreIndex CoreType EClass
--- --------- -------- ------
 0     0        P         2
 1     0        P         2
 2     1        P         2
 3     1        P         2
 4     2        E         0
 5     3        E         0
 6     4        E         0
 7     5        E         0
 8     6        E         0
 9     7        E         0
10     8        E         0
11     9        E         0
12    10        E         0   # LP-E
13    11        E         0   # LP-E

Caveats

    AMD hybrid parts are not supported yet – their scheduler hints use different values.

    Windows versions prior to 1903 lack the EfficiencyClass field.

    Results can change after a firmware update that re-orders logical-CPU numbers; rerun the script once after a BIOS update.

License

MIT – do whatever you like, just keep the copyright header.

Enjoy painless core mapping!
