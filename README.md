# Intel Hybrid‑Core Mapper – *PowerShell‑only*
> Map Task‑Manager CPU graphs to **P‑** and **E‑cores** on Windows – no installs, no admin rights.

---

## ✨ Features
- **100 % native** – pure PowerShell + Win32 API (`GetSystemCpuSetInformation`).
- **Zero footprint** – runs in a stock Windows image; nothing to install or unblock.
- **Works on every Intel hybrid CPU** from 12th Gen (Alder Lake) to Core Ultra (Meteor Lake).
- **Consistent, deterministic output** – fixes common struct‑layout bugs that return random values.

---

## Requirements
|                | Minimum |
|----------------|---------|
| **OS**         | Windows 10 21H1 or newer (EfficiencyClass first surfaced in 1903) |
| **Shell**      | Windows PowerShell 5.x **or** PowerShell 7+ (x86 & x64) |
| **Privileges** | *None* – standard user session works |

> **Note**   AMD hybrid parts are *not* yet supported (they use different scheduler hints).

---

## How it works
1. The script compiles ≈ 35 lines of C# at runtime with `Add-Type`.
2. Calls **`GetSystemCpuSetInformation`** twice (probe size → retrieve data).
3. Deserialises every `SYSTEM_CPU_SET_INFORMATION` structure.
4. Detects the *highest* `EfficiencyClass` byte – Intel assigns the largest value to P‑cores.
5. Emits a readable table mapping Task‑Manager CPU graphs (0…n) to real core types.

---

## Usage
```powershell
# basic
PS> .\Get‑HybridCoreMap.ps1

# get raw objects – great for piping or testing
PS> .\Get‑HybridCoreMap.ps1 -Raw

# machine‑readable JSON
PS> .\Get‑HybridCoreMap.ps1 -Json | ConvertFrom-Json
```

### Options
| Switch | Description |
|--------|-------------|
| `-Raw` | Return the array of CPU‑set structures instead of a formatted table |
| `-Json` | Output structured JSON (handy for logs/dashboards) |

---

## Example output (Core Ultra 7 155U – 2 P + 8 E + 2 LP‑E)
```text
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
12    10        E         0
13    11        E         0
```

---

## Caveats
* Windows versions prior to 1903 lack the `EfficiencyClass` field – the script will exit.
* BIOS/firmware updates can renumber logical processors – rerun the script once after updating.
* Currently limited to Intel hybrid CPUs.

---

## License
[MIT](LICENSE) – free to use, modify, and distribute.  Pull requests are welcome!

