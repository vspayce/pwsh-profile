# Alias(Windows): du
function Get-FolderSize {
    <#
    .SYNOPSIS
        Size of every subfolder in one fast parallel pass, biggest first, with a bar - find what is filling a disk.
    .DESCRIPTION
        Uses the same trick as the Canopy file browser: walk the tree ONCE and roll each
        folder's total up into its parent as you leave it, so every folder's size comes from
        a single scan instead of re-scanning each subfolder. The walk is compiled C# and the
        top-level folders are scanned in parallel on all CPU cores. File sizes come straight
        from the directory listing (no extra lookup per file).

        Junctions and symbolic links are not followed (nothing is counted twice, no loops).
        Folders you can't read are skipped and reported in the summary line.

        Output is objects, so you can filter and sort: the Bytes property is the raw size.
    .EXAMPLE
        du C:\Users
    .EXAMPLE
        du C:\ -Depth 2 -Top 30        # also rank folders one level further down
    .EXAMPLE
        Get-FolderSize D:\Shares | Where-Object Bytes -gt 10GB
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][string]$Path = '.',
        [int]$Top = 20,
        [ValidateRange(1, 10)][int]$Depth = 1,
        # Scan on one thread (useful for slow network shares or spinning disks)
        [switch]$NoParallel
    )

    if (-not ('PwshProfile.FolderSizer' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace PwshProfile {
    public sealed class FolderTotal {
        public string Path;
        public int Depth;
        public long Bytes;
        public long Files;
        public long Folders;
    }

    public sealed class FolderScan {
        public FolderTotal Root;
        public List<FolderTotal> Folders = new List<FolderTotal>();
        public long LooseFileBytes;   // files sitting directly in the root
        public long LooseFiles;
        public int Denied;
    }

    public static class FolderSizer {
        public static FolderScan Scan(string root, int keepDepth, bool parallel) {
            var scan = new FolderScan();
            var dir = new DirectoryInfo(root);
            var t = new FolderTotal { Path = dir.FullName, Depth = 0 };
            scan.Root = t;

            var subdirs = new List<DirectoryInfo>();
            try {
                foreach (var item in dir.EnumerateFileSystemInfos()) {
                    if ((item.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    var sub = item as DirectoryInfo;
                    if (sub != null) { subdirs.Add(sub); continue; }
                    long len = ((FileInfo)item).Length;
                    t.Bytes += len; t.Files++;
                    scan.LooseFileBytes += len; scan.LooseFiles++;
                }
            } catch (UnauthorizedAccessException) { scan.Denied++; return scan; }

            var results = new FolderTotal[subdirs.Count];
            var lists = new List<FolderTotal>[subdirs.Count];
            Action<int> work = i => {
                var keep = new List<FolderTotal>();
                results[i] = Walk(subdirs[i], 1, keepDepth, keep, scan);
                lists[i] = keep;
            };
            if (parallel) Parallel.For(0, subdirs.Count, work);
            else for (int i = 0; i < subdirs.Count; i++) work(i);

            for (int i = 0; i < subdirs.Count; i++) {
                t.Bytes += results[i].Bytes;
                t.Files += results[i].Files;
                t.Folders += results[i].Folders + 1;
                scan.Folders.AddRange(lists[i]);
            }
            return scan;
        }

        // Depth-first; a folder's total is complete when we leave it and is added
        // to its parent's running total (the Canopy trick).
        static FolderTotal Walk(DirectoryInfo dir, int depth, int keepDepth, List<FolderTotal> keep, FolderScan scan) {
            var t = new FolderTotal { Path = dir.FullName, Depth = depth };
            try {
                foreach (var item in dir.EnumerateFileSystemInfos()) {
                    if ((item.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                    var sub = item as DirectoryInfo;
                    if (sub != null) {
                        var child = Walk(sub, depth + 1, keepDepth, keep, scan);
                        t.Bytes += child.Bytes;
                        t.Files += child.Files;
                        t.Folders += child.Folders + 1;
                    } else {
                        t.Bytes += ((FileInfo)item).Length;
                        t.Files++;
                    }
                }
            }
            catch (UnauthorizedAccessException) { Interlocked.Increment(ref scan.Denied); }
            catch (IOException) { Interlocked.Increment(ref scan.Denied); }
            if (depth <= keepDepth) keep.Add(t);
            return t;
        }
    }
}
'@
    }

    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $scan = [PwshProfile.FolderSizer]::Scan($root, $Depth, -not $NoParallel)
    $sw.Stop()

    $fmt = {
        param([long]$b)
        if ($b -ge 1TB) { '{0:N1} TB' -f ($b / 1TB) }
        elseif ($b -ge 1GB) { '{0:N1} GB' -f ($b / 1GB) }
        elseif ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) }
        elseif ($b -ge 1KB) { '{0:N0} KB' -f ($b / 1KB) }
        else { "$b B" }
    }
    $total = [Math]::Max($scan.Root.Bytes, 1)
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($f in $scan.Folders) { $rows.Add($f) }
    if ($scan.LooseFiles -gt 0) {
        $rows.Add([PSCustomObject]@{ Path = [IO.Path]::Combine($root, '(files here)'); Depth = 1; Bytes = $scan.LooseFileBytes; Files = $scan.LooseFiles })
    }

    # Register a table view once per session (custom objects with 5+ columns would otherwise print as a list)
    if (-not $global:PwshProfileState.FolderSizeFormat) {
        $xml = @'
<Configuration><ViewDefinitions><View><Name>PwshProfile.FolderSize</Name>
<ViewSelectedBy><TypeName>PwshProfile.FolderSize</TypeName></ViewSelectedBy>
<TableControl><TableHeaders>
<TableColumnHeader><Label>Folder</Label></TableColumnHeader>
<TableColumnHeader><Label>Size</Label><Alignment>Right</Alignment></TableColumnHeader>
<TableColumnHeader><Label>Pct</Label><Alignment>Right</Alignment></TableColumnHeader>
<TableColumnHeader><Label>Bar</Label><Width>21</Width></TableColumnHeader>
<TableColumnHeader><Label>Files</Label><Alignment>Right</Alignment></TableColumnHeader>
</TableHeaders><TableRowEntries><TableRowEntry><TableColumnItems>
<TableColumnItem><PropertyName>Folder</PropertyName></TableColumnItem>
<TableColumnItem><PropertyName>Size</PropertyName></TableColumnItem>
<TableColumnItem><PropertyName>Pct</PropertyName></TableColumnItem>
<TableColumnItem><PropertyName>Bar</PropertyName></TableColumnItem>
<TableColumnItem><ScriptBlock>'{0:N0}' -f $_.Files</ScriptBlock></TableColumnItem>
</TableColumnItems></TableRowEntry></TableRowEntries></TableControl></View></ViewDefinitions></Configuration>
'@
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "pwshprofile-foldersize-$PID.format.ps1xml"
        [IO.File]::WriteAllText($tmp, $xml)
        try { Update-FormatData -PrependPath $tmp; $global:PwshProfileState.FolderSizeFormat = $true }
        finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
    }

    $out = $rows | Sort-Object Bytes -Descending | Select-Object -First $Top | ForEach-Object {
        $pct = 100.0 * $_.Bytes / $total
        [PSCustomObject]@{
            PSTypeName = 'PwshProfile.FolderSize'
            Folder = ('  ' * ($_.Depth - 1)) + $_.Path.Substring($root.Length).TrimStart('\', '/')
            Size   = & $fmt $_.Bytes
            Pct    = '{0:N1}%' -f $pct
            Bar    = '#' * [int][Math]::Round($pct / 5)
            Files  = $_.Files
            Bytes  = $_.Bytes
            Path   = $_.Path
        }
    }

    # Summary first (as a header), then the objects - so piping and $x = du ... still work
    $note = '{4}: {0} in {1:N0} files, {2:N0} folders - scanned in {3:N2}s' -f (& $fmt $scan.Root.Bytes), $scan.Root.Files, $scan.Root.Folders, $sw.Elapsed.TotalSeconds, $root
    if ($scan.Denied) { $note += " ($($scan.Denied) folders skipped: access denied)" }
    Write-Host $note -ForegroundColor DarkGray
    $out
}
