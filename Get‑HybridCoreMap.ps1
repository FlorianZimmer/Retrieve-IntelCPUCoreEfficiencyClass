<#
.SYNOPSIS
 Maps Task‑Manager CPU graphs to Intel **P‑, E‑, and LP‑E** cores.

.DESCRIPTION
 Pure PowerShell – no external modules or admin rights.  The script calls the
 Windows kernel’s *GetSystemCpuSetInformation* API, reads each logical CPU’s
 **EfficiencyClass** and **SchedulingClass** bytes, and labels the result:

 * **P**  – performance core (highest EfficiencyClass)
 * **E**  – efficiency core (EfficiencyClass = min, SchedulingClass > 0)
 * **LP‑E** – low‑power efficiency core (EfficiencyClass = min, SchedulingClass = 0)

Works on Intel hybrid CPUs from 12th‑Gen (Alder Lake) through Core Ultra.

.PARAMETER Raw
 Return the raw object array instead of a formatted table.

.PARAMETER Json
 Output structured JSON (depth 3).

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1           # pretty table

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1 -Raw | Where‑Object CoreType -eq 'LP-E'

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1 -Json | Out‑File coremap.json
#>

[CmdletBinding()]
param(
    [switch]$Raw,
    [switch]$Json
)

if ($Raw -and $Json) {
    throw 'Specify **either** -Raw **or** -Json, not both.'
}

# -----------------------  compile helper type once  --------------------
if (-not ('CpuSetNative' -as [type])) {
    $src = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CpuSetNative
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SYSTEM_CPU_SET_INFORMATION
    {
        public UInt32 Size;
        public int    Type;              // 0 = CpuSet
        public SYSTEM_CPU_SET CpuSet;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SYSTEM_CPU_SET
    {
        public UInt32 Id;
        public UInt16 Group;
        public byte   LogicalProcessorIndex;
        public byte   CoreIndex;
        public byte   LastLevelCacheIndex;
        public byte   NumaNodeIndex;
        public byte   EfficiencyClass;   // 0 = most efficient … higher = faster
        public byte   AllFlags;
        public byte   SchedulingClass;   // 0 = LP‑E, >0 = E (Meteor Lake)
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 3)]
        public byte[] Padding;
        public UInt64 AllocationTag;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemCpuSetInformation(
        IntPtr info, int len, ref int retLen, IntPtr proc, uint flags);

    public static SYSTEM_CPU_SET[] GetCpuSets()
    {
        int bytes = 0;
        GetSystemCpuSetInformation(IntPtr.Zero, 0, ref bytes, IntPtr.Zero, 0);
        if (bytes == 0) return Array.Empty<SYSTEM_CPU_SET>();

        IntPtr buf = Marshal.AllocHGlobal(bytes);
        try
        {
            if (!GetSystemCpuSetInformation(buf, bytes, ref bytes, IntPtr.Zero, 0))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());

            var list = new List<SYSTEM_CPU_SET>();
            int off = 0;
            while (off < bytes)
            {
                IntPtr p = IntPtr.Add(buf, off);
                var info = Marshal.PtrToStructure<SYSTEM_CPU_SET_INFORMATION>(p);
                if (info.Type == 0) list.Add(info.CpuSet);
                off += (int)info.Size;
            }
            return list.ToArray();
        }
        finally { Marshal.FreeHGlobal(buf); }
    }
}
"@
    Add-Type $src -ErrorAction Stop
}

# ---------------------------  gather data  -----------------------------
$sets = [CpuSetNative]::GetCpuSets()
if (-not $sets) {
    Write-Error 'GetSystemCpuSetInformation not supported on this OS (< Windows 10 1903).'
    return
}

$rows = foreach ($s in $sets) {
    [pscustomobject]@{
        CPU        = $s.LogicalProcessorIndex
        CoreIndex  = $s.CoreIndex
        EClass     = $s.EfficiencyClass
        SClass     = $s.SchedulingClass
    }
}

# --------  classification rules  --------
$maxEClass = ($rows | Measure-Object EClass -Maximum).Maximum   # P‑cores
$minEClass = ($rows | Measure-Object EClass -Minimum).Minimum   # E / LP‑E cores

$rows | ForEach-Object {
    $ctype = if ($_.EClass -eq $maxEClass) {
        'P'
    } elseif ($_.EClass -eq $minEClass -and $_.SClass -eq 0) {
        'LP-E'
    } else {
        'E'
    }
    $_ | Add-Member CoreType $ctype -Force
}

$rows = $rows | Sort-Object CPU

# ---------------------------  output  ----------------------------------
if ($Json) {
    $rows | ConvertTo-Json -Depth 3
} elseif ($Raw) {
    $rows
} else {
    $rows | Format-Table CPU,CoreIndex,CoreType,EClass,SClass
}
