Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class CpuSetNative
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SYSTEM_CPU_SET_INFORMATION
    {
        public UInt32 Size;
        public int Type; // 0 = CpuSet
        public SYSTEM_CPU_SET CpuSet;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SYSTEM_CPU_SET
    {
        public UInt32 Id;
        public UInt16 Group;
        public byte LogicalProcessorIndex;
        public byte CoreIndex;
        public byte LastLevelCacheIndex;
        public byte NumaNodeIndex;
        public byte EfficiencyClass; // correct order!
        public byte AllFlags;
        public UInt32 Reserved;
        public UInt64 AllocationTag;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemCpuSetInformation(
        IntPtr info, int len, ref int returned, IntPtr proc, uint flags);

    // return an array that PowerShell can consume
    public static SYSTEM_CPU_SET[] GetCpuSets()
    {
        int need = 0;
        GetSystemCpuSetInformation(IntPtr.Zero, 0, ref need, IntPtr.Zero, 0);
        if (need == 0) return Array.Empty<SYSTEM_CPU_SET>();

        IntPtr buf = Marshal.AllocHGlobal(need);
        try
        {
            if (!GetSystemCpuSetInformation(buf, need, ref need, IntPtr.Zero, 0))
                throw new System.ComponentModel.Win32Exception(
                      Marshal.GetLastWin32Error());

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

$sets = [CpuSetNative]::GetCpuSets()
$maxClass = ($sets | ForEach-Object EfficiencyClass | Measure-Object -Maximum).Maximum
$rows = foreach ($s in $sets) {
    [pscustomobject]@{
        CPU = $s.LogicalProcessorIndex
        CoreIndex = $s.CoreIndex
        CoreType = if ($s.EfficiencyClass -eq $maxClass) { 'P' } else { 'E' }
        EClass = $s.EfficiencyClass
    }
}

$rows | Sort-Object CPU | Format-Table
