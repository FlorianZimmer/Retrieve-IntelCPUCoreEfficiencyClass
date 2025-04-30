<#!
.SYNOPSIS
 Maps Task‑Manager CPU graphs to Intel P‑ and E‑cores.

.DESCRIPTION
 Pure PowerShell script – no external modules or admin rights – that queries the
 Windows kernel’s GetSystemCpuSetInformation API, reads the EfficiencyClass
 byte for every logical processor, and labels each one as a P‑ (performance) or
 E‑ (efficiency) core.  Works on Intel hybrid‑architecture CPUs from 12th‑Gen
 through Core Ultra.

.PARAMETER Raw
 Returns the raw array of [pscustomobject] rows (one per logical CPU) instead of
 a formatted table.

.PARAMETER Json
 Serialises the rows to JSON (Depth 3) – for logs, dashboards, etc.

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1 -Raw | Where‑Object CoreType -eq 'P'

.EXAMPLE
 PS> .\Get‑HybridCoreMap.ps1 -Json | Out‑File coremap.json

#>

[CmdletBinding()]
param(
    [switch]$Raw,
    [switch]$Json
)

if ($Raw -and $Json) {
    throw "Specify **either** -Raw **or** -Json, not both."
}

# -------------------------  native helper  -----------------------------
Add-Type -Language C# @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CpuSetNative
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SYSTEM_CPU_SET_INFORMATION
    {
        public UInt32 Size;
        public int    Type;          // 0 = CpuSet
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
        public byte   AllFlags;          // bit0 = parked, bit1 = allocated, …
        public UInt32 Reserved;
        public UInt64 AllocationTag;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemCpuSetInformation(
        IntPtr info, int len, ref int returned, IntPtr process, uint flags);

    public static SYSTEM_CPU_SET[] GetCpuSets()
    {
        int need = 0;
        GetSystemCpuSetInformation(IntPtr.Zero, 0, ref need, IntPtr.Zero, 0);
        if (need == 0)
            return Array.Empty<SYSTEM_CPU_SET>();

        IntPtr buf = Marshal.AllocHGlobal(need);
        try
        {
            if (!GetSystemCpuSetInformation(buf, need, ref need, IntPtr.Zero, 0))
                throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());

            var list = new List<SYSTEM_CPU_SET>();
            int off = 0;
            while (off < need)
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

# ---------------------------  gather data  -----------------------------
$sets = [CpuSetNative]::GetCpuSets()
if (-not $sets) {
    Write-Error "GetSystemCpuSetInformation not supported on this OS (< Windows 10 1903)."
    return
}

$maxEClass = ($sets | ForEach-Object EfficiencyClass | Measure-Object -Maximum).Maximum
$rows = foreach ($s in $sets) {
    [pscustomobject]@{
        CPU       = $s.LogicalProcessorIndex
        CoreIndex = $s.CoreIndex
        CoreType  = if ($s.EfficiencyClass -eq $maxEClass) { 'P' } else { 'E' }
        EClass    = $s.EfficiencyClass
    }
}

# ---------------------------  output  ----------------------------------
$rows = $rows | Sort-Object CPU

if ($Json) {
    $rows | ConvertTo-Json -Depth 3
}
elseif ($Raw) {
    $rows
}
else {
    $rows | Format-Table
}
