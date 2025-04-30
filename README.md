# Intel Hybrid‑Core Mapper – *PowerShell‑only*
> Map Task‑Manager CPU graphs to **P‑**, **E‑**, and **LP‑E** cores on Windows – no installs, no admin rights.

---

## ✨ Features
- **Differentiates all three Intel core types** – Performance (P), Efficiency (E), and Low‑Power Efficiency (LP‑E) on Meteor Lake / Core Ultra.
- **100 % native** – pure PowerShell + Win32 API (`GetSystemCpuSetInformation`).
- **Zero footprint** – runs in a stock Windows image; nothing to install or unblock.
- **Works on every Intel hybrid CPU** from 12th Gen (Alder Lake) to Core Ultra.
- **Consistent, deterministic output** – validated struct layout eliminates random values.

---

## Requirements
|                | Minimum |
|----------------|---------|
| **OS**         | Windows 10 21H1 or newer (EfficiencyClass **and** SchedulingClass exposed) |
| **Shell**      | Windows PowerShell 5.x **or** PowerShell 7+ (x86 & x64) |
| **Privileges** | *None* – standard user session works |

> **Note**   AMD hybrid parts are *not* yet supported (different scheduler hints).

---

## How it works
1. Compiles ≈ 40 lines of C# at runtime with `Add-Type`.
2. Calls **`GetSystemCpuSetInformation`** twice to pull the complete CPU‑set list.
3. Deserialises each `SYSTEM_CPU_SET_INFORMATION` structure.
4. Uses two scheduler hints per logical CPU  
   • **EfficiencyClass** → distinguishes P vs. non‑P  
   • **SchedulingClass** → distinguishes LP‑E vs. E
5. Emits a neat table that maps Task‑Manager CPU graphs (0…n) to **P / E / LP‑E**.

---

## Usage
```powershell
# default table
PS> .\Get‑HybridCoreMap.ps1

# raw objects for further processing
PS> .\Get‑HybridCoreMap.ps1 -Raw

# JSON for dashboards / logging
PS> .\Get‑HybridCoreMap.ps1 -Json | Out‑File coremap.json
```

---

## Example output (Core Ultra 7 155U – 2 P + 8 E + 2 LP‑E)
```text
CPU CoreIndex CoreType EClass SClass
--- --------- -------- ------ ------
 0     0        P         1      2
 1     0        P         1      2
 2     2        E         0      1
 3     3        E         0      1
 4     4        E         0      1
 5     5        E         0      1
 6     6        E         0      1
 7     7        E         0      1
 8     8        E         0      1
 9     9        E         0      1
10    10        P         1      2
11    10        P         1      2
12    12       LP‑E       0      0
13    13       LP‑E       0      0
```

---

## Caveats
* Windows versions prior to 1903 lack the required scheduler hints.
* BIOS / firmware updates can renumber logical processors – rerun the script afterwards.
* Currently limited to Intel hybrid CPUs; AMD support is on the roadmap.

---

## License
MIT – use, modify, and distribute freely.  Pull requests welcome!

