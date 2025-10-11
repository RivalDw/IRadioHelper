# Simple M3U Creator - PowerShell 7+ (Optimized Memory Usage)

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "=== POWERShell 7+ REQUIRED ===" -ForegroundColor Red
    Write-Host "Current PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "This script requires PowerShell 7.0 or higher for parallel processing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please download PowerShell 7+ from:" -ForegroundColor White
    Write-Host "https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press any key to open download page or Ctrl+C to cancel..." -ForegroundColor White
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Open download page
    Start-Process "https://github.com/PowerShell/PowerShell/releases/latest"
    
    exit 1
}

Write-Host "PowerShell $($PSVersionTable.PSVersion) detected - proceeding with script..." -ForegroundColor Green

chcp 65001 | Out-Null
$Host.UI.RawUI.WindowTitle = "Simple M3U Creator - PowerShell 7+ (Memory Optimized)"

# Paths
$music_path = "D:\Music"
$main_playlist = "D:\Music\playlists\genres\music.m3u"
$genre_dir = "D:\Music\playlists\genres"
$logFile = Join-Path $PSScriptRoot "playlist_log.txt"

# Create directories
New-Item -ItemType Directory -Force -Path "D:\Music\playlists" | Out-Null
New-Item -ItemType Directory -Force -Path $genre_dir | Out-Null

# Clean old playlists
if (Test-Path $main_playlist) { Remove-Item $main_playlist -Force }
Get-ChildItem "$genre_dir\*.m3u" | Remove-Item -Force

$total_files = 0
$files_with_genre = 0

$genreCount = @{}
$genreTracks = @{}

"=== Start: $(Get-Date) ===" | Out-File -FilePath $logFile -Encoding UTF8

# Find audio files
$audioExtensions = @(".mp3", ".flac", ".wav", ".m4a", ".aac", ".ogg", ".wma")
Write-Host "Searching for audio files..." -ForegroundColor Yellow
$audioFiles = Get-ChildItem -Path $music_path -Recurse -File | Where-Object { $_.Extension -in $audioExtensions }

Write-Host "Found $($audioFiles.Count) audio files" -ForegroundColor Cyan
$total_files = $audioFiles.Count
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Force garbage collection before starting
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Function to sanitize file names
function SanitizeFileName {
    param([string]$name)
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($c in $invalidChars) {
        $name = $name.Replace($c,'_')
    }
    return ($name -replace '\s+', ' ').Trim()
}

# Function to display progress bar
function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$Current,
        [int]$Total,
        [switch]$Completed
    )
    
    if ($Completed) {
        Write-Progress -Activity $Activity -Status "Completed" -Completed
        return
    }
    
    $PercentComplete = if ($Total -gt 0) { [math]::Min(100, [math]::Max(0, [int](($Current / $Total) * 100))) } else { 0 }
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

# Function to get memory usage
function Get-MemoryUsage {
    $process = Get-Process -Id $PID
    $memoryMB = [math]::Round($process.WorkingSet64 / 1MB, 2)
    return $memoryMB
}

# Function to process files in batches (reduces memory pressure)
function Process-FileBatch {
    param(
        [array]$Files,
        [int]$BatchSize = 100
    )
    
    $results = [System.Collections.Generic.List[object]]::new()
    $batchCount = [math]::Ceiling($Files.Count / $BatchSize)
    
    for ($i = 0; $i -lt $batchCount; $i++) {
        $startIndex = $i * $BatchSize
        $endIndex = [math]::Min($startIndex + $BatchSize - 1, $Files.Count - 1)
        $batchFiles = $Files[$startIndex..$endIndex]
        
        Write-Host "Processing batch $($i + 1)/$batchCount (Memory: $(Get-MemoryUsage) MB)" -ForegroundColor Gray
        
        $batchResults = $batchFiles | ForEach-Object -Parallel {
            # Minimal function definitions to reduce memory footprint
            function Parse-FileName { 
                param([string]$filename, [string]$directory)
                
                if ($directory -and $directory -ne "Music" -and $directory -ne "D:\Music") {
                    $cleanTitle = $filename -replace '^\d+\.\s*', '' -replace '\.\w+$', ''
                    return @{ Artist = $directory.Trim(); Title = $cleanTitle.Trim() }
                }
                
                if ($filename -match " - ") {
                    $parts = $filename -split " - ", 2
                    $artist = $parts[0].Trim() -replace '^\d+\.\s*', ''
                    $title = $parts[1].Trim() -replace '\.\w+$', ''
                    return @{ Artist = $artist; Title = $title }
                }
                
                if ($filename -match '^\d+\.\s*.+') {
                    $cleanTitle = $filename -replace '^\d+\.\s*', '' -replace '\.\w+$', ''
                    return @{ Artist = "Unknown Artist"; Title = $cleanTitle.Trim() }
                }
                
                return $null
            }

            function Get-GenreFromArtist { 
                param([string]$artist)
                $a = $artist.ToLower()
                if ($a -match "oomph|rammstein|megaherz|eisbrecher|kmfdm|ministry") { return "Industrial Metal" }
                if ($a -match "slipknot|korn|system of a down|deftones") { return "Alternative Metal" }
                if ($a -match "metallica|iron maiden|judas priest") { return "Heavy Metal" }
                if ($a -match "cannibal corpse|marduk|darkthrone|mayhem") { return "Extreme Metal" }
                if ($a -match "bloodhound gang|green day|blink.182|offspring") { return "Punk Rock" }
                if ($a -match "nirvana|pearl jam|soundgarden|alice in chains") { return "Grunge" }
                if ($a -match "ac.dc|guns n.roses|aerosmith") { return "Hard Rock" }
                if ($a -match "eminem|50 cent|dr.dre|snoop dogg|tupac|notorious b.i.g") { return "Hip-Hop" }
                if ($a -match "rihanna|britney spears|justin bieber|taylor swift") { return "Pop" }
                if ($a -match "daft punk|chemical brothers|prodigy|fatboy slim") { return "Electronic" }
                return "Unknown"
            }

            function Get-GenreFromTags { 
                param([string]$filePath)
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $folder = $shell.Namespace((Split-Path $filePath))
                    $file = $folder.ParseName((Split-Path $filePath -Leaf))
                    $g = $folder.GetDetailsOf($file, 16)
                    if ([string]::IsNullOrWhiteSpace($g)) { return $null }
                    return $g.Trim()
                } catch { 
                    return $null 
                }
            }

            $file = $_
            
            # Safe directory extraction
            $directory = $null
            try {
                if ($file.DirectoryName) {
                    $directory = Split-Path $file.DirectoryName -Leaf -ErrorAction SilentlyContinue
                }
            } catch {
                # Ignore errors, use fallback
            }
            
            if (-not $directory -and $file.FullName) {
                try {
                    $parentDir = [System.IO.Path]::GetDirectoryName($file.FullName)
                    if ($parentDir) {
                        $directory = [System.IO.Path]::GetFileName($parentDir)
                    }
                } catch {
                    $directory = $null
                }
            }
            
            $parsed = Parse-FileName -filename $file.BaseName -directory $directory
            
            if ($parsed) {
                $artist = $parsed.Artist
                $title = $parsed.Title
            } else {
                $artist = if ($directory -and $directory -ne "Music" -and $directory -ne "D:\Music") { 
                    $directory 
                } else { 
                    "Unknown Artist" 
                }
                $title = $file.BaseName -replace '^\d+\.\s*', ''
            }

            $genre = $null
            try {
                $genre = Get-GenreFromTags -filePath $file.FullName
            } catch {
                $genre = $null
            }
            
            if (-not $genre -or [string]::IsNullOrWhiteSpace($genre)) { 
                $genre = Get-GenreFromArtist -artist $artist 
            }

            # Return minimal object
            [PSCustomObject]@{
                FilePath = $file.FullName
                Artist = $artist
                Title = $title
                Genre = $genre
            }
        } -ThrottleLimit 4  # Reduced throttle limit to save memory
        
        $results.AddRange($batchResults)
        
        # Force garbage collection after each batch
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    
    return $results
}

# Function to merge similar playlists (memory optimized)
function Merge-SimilarPlaylists {
    param([string]$playlistsDir)
    
    Write-Host "Looking for similar playlists to merge..." -ForegroundColor Yellow
    
    $allPlaylists = Get-ChildItem -Path $playlistsDir -Filter "*.m3u" -File
    $playlistGroups = @{}
    
    # Group playlists
    Write-Host "Grouping playlists..." -ForegroundColor Cyan
    $groupCount = 0
    foreach ($playlist in $allPlaylists) {
        $groupCount++
        Show-Progress -Activity "Grouping playlists" -Status "Processing $($playlist.Name)" -Current $groupCount -Total $allPlaylists.Count
        
        $baseName = $playlist.BaseName
        $genres = $baseName -split '_' | ForEach-Object { $_.Trim() } | Sort-Object
        $genreKey = ($genres -join '_').ToLower()
        
        if (-not $playlistGroups.ContainsKey($genreKey)) {
            $playlistGroups[$genreKey] = [System.Collections.Generic.List[string]]::new()
        }
        $playlistGroups[$genreKey].Add($playlist.FullName)
    }
    Show-Progress -Activity "Grouping playlists" -Completed
    
    $mergedCount = 0
    $removedCount = 0
    $totalGroups = $playlistGroups.Count
    $currentGroup = 0
    
    # Process each group
    foreach ($genreKey in $playlistGroups.Keys) {
        $currentGroup++
        $group = $playlistGroups[$genreKey]
        
        if ($group.Count -gt 1) {
            $status = "Merging $($group.Count) playlists"
            Show-Progress -Activity "Merging similar playlists" -Status $status -Current $currentGroup -Total $totalGroups
            
            Write-Host "Merging $($group.Count) playlists for genres: $genreKey" -ForegroundColor Cyan
            
            # Use HashSet for track deduplication (memory efficient)
            $allTracks = @{}
            
            foreach ($playlistFile in $group) {
                $content = Get-Content -Path $playlistFile -Encoding UTF8
                $currentTrack = $null
                
                foreach ($line in $content) {
                    if ($line.StartsWith("#EXTINF:")) {
                        $currentTrack = $line
                    } elseif ($line -and -not $line.StartsWith("#EXTM3U")) {
                        if ($currentTrack) {
                            $allTracks[$line] = $currentTrack
                            $currentTrack = $null
                        }
                    }
                }
            }
            
            # Create merged playlist
            if ($allTracks.Count -gt 0) {
                $genresArray = $genreKey -split '_' | ForEach-Object { 
                    (Get-Culture).TextInfo.ToTitleCase($_.ToLower())
                }
                $newName = ($genresArray -join '_') + ".m3u"
                $newPath = Join-Path $playlistsDir $newName
                
                # Stream write to file instead of building in memory
                $stream = [System.IO.StreamWriter]::new($newPath, $false, [System.Text.Encoding]::UTF8)
                $stream.WriteLine("#EXTM3U")
                
                foreach ($trackPath in $allTracks.Keys) {
                    $stream.WriteLine($allTracks[$trackPath])
                    $stream.WriteLine($trackPath)
                }
                $stream.Close()
                
                # Remove old playlists
                foreach ($oldPlaylist in $group) {
                    if ($oldPlaylist -ne $newPath) {
                        Remove-Item -Path $oldPlaylist -Force
                        $removedCount++
                    }
                }
                
                $mergedCount++
                Write-Host "  -> Created merged playlist: $newName ($($allTracks.Count) tracks)" -ForegroundColor Green
            }
            
            # Clean up
            $allTracks.Clear()
        }
    }
    
    Show-Progress -Activity "Merging similar playlists" -Completed
    Write-Host "Merge completed: $mergedCount merged playlists, $removedCount old playlists removed" -ForegroundColor Green
    return @{ Merged = $mergedCount; Removed = $removedCount }
}

# Main processing with memory monitoring
Write-Host "Starting processing with memory optimization..." -ForegroundColor Yellow
Write-Host "Initial memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Gray

# Process files in batches to control memory usage
$results = Process-FileBatch -Files $audioFiles -BatchSize 200

Write-Host "Processing completed. Memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Green
Write-Host "Building playlists..." -ForegroundColor Yellow

# Build main playlist with streaming to avoid large memory usage
Write-Host "Building main playlist..." -ForegroundColor Cyan
$mainStream = [System.IO.StreamWriter]::new($main_playlist, $false, [System.Text.Encoding]::UTF8)
$mainStream.WriteLine("#EXTM3U")

$currentTrack = 0
foreach ($track in $results) {
    $currentTrack++
    if ($currentTrack % 100 -eq 0) {
        Show-Progress -Activity "Building main playlist" -Status "Processing track $currentTrack/$total_files" -Current $currentTrack -Total $total_files
    }
    
    $mainStream.WriteLine("#EXTINF:-1,$($track.Artist) - $($track.Title)")
    $mainStream.WriteLine($track.FilePath)

    # Build genre collections
    if (-not $genreCount.ContainsKey($track.Genre)) {
        $genreCount[$track.Genre] = 0
        $genreTracks[$track.Genre] = [System.Collections.Generic.List[object]]::new()
    }
    $genreCount[$track.Genre]++
    $genreTracks[$track.Genre].Add(@{ FilePath=$track.FilePath; Artist=$track.Artist; Title=$track.Title })

    if ($track.Genre -ne "Unknown") { $files_with_genre++ }
}

$mainStream.Close()
Show-Progress -Activity "Building main playlist" -Completed

# Write genre playlists with streaming
Write-Host "Writing genre playlists..." -ForegroundColor Yellow
$genreKeys = @($genreCount.Keys)
$currentGenre = 0

foreach ($genre in $genreKeys) {
    $currentGenre++
    $count = $genreCount[$genre]
    
    Show-Progress -Activity "Writing genre playlists" -Status "Processing $genre ($count tracks)" -Current $currentGenre -Total $genreKeys.Count
    
    if ($genre -ne "Unknown" -and $count -gt 10) {
        $genrePlaylistName = ($genre -split '[;|,]').Trim() | Select-Object -First 1
        $genrePlaylistName = SanitizeFileName($genrePlaylistName)

        if ($genrePlaylistName.Length -gt 50) { 
            $genrePlaylistName = $genrePlaylistName.Substring(0,50) 
        }

        $genrePlaylist = Join-Path $genre_dir "$genrePlaylistName.m3u"
        $stream = [System.IO.StreamWriter]::new($genrePlaylist, $false, [System.Text.Encoding]::UTF8)
        $stream.WriteLine("#EXTM3U")
        
        foreach ($track in $genreTracks[$genre]) {
            $stream.WriteLine("#EXTINF:-1,$($track.Artist) - $($track.Title)")
            $stream.WriteLine($track.FilePath)
        }
        $stream.Close()
    }
}

Show-Progress -Activity "Writing genre playlists" -Completed

# Clean up results to free memory
$results = $null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Memory after cleanup: $(Get-MemoryUsage) MB" -ForegroundColor Gray

# Merge similar playlists
$mergeResults = Merge-SimilarPlaylists -playlistsDir $genre_dir

# Final cleanup
$genreCount.Clear()
$genreTracks.Clear()
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

# Logging
$stopwatch.Stop()
"" | Out-File -FilePath $logFile -Append
"=== Completed: $(Get-Date) ===" | Out-File -FilePath $logFile -Append
"Execution time: $($stopwatch.Elapsed.ToString())" | Out-File -FilePath $logFile -Append
"Files processed: $total_files" | Out-File -FilePath $logFile -Append
"Files with genre: $files_with_genre" | Out-File -FilePath $logFile -Append
"Files without genre: $($total_files - $files_with_genre)" | Out-File -FilePath $logFile -Append
"Genres found: $($genreCount.Keys.Count)" | Out-File -FilePath $logFile -Append
"Playlists merged: $($mergeResults.Merged)" | Out-File -FilePath $logFile -Append
"Playlists removed: $($mergeResults.Removed)" | Out-File -FilePath $logFile -Append
"Peak memory usage: $(Get-MemoryUsage) MB" | Out-File -FilePath $logFile -Append

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "COMPLETED! (Memory Optimized)" -ForegroundColor Green
Write-Host "Main playlist: $main_playlist" -ForegroundColor Cyan
Write-Host "Genre playlists: $genre_dir\" -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host "Total files processed: $total_files in $($stopwatch.Elapsed.ToString())" -ForegroundColor Yellow
Write-Host "Files with genre detected: $files_with_genre" -ForegroundColor Yellow
Write-Host "Unique genres found: $($genreKeys.Count)" -ForegroundColor Yellow
Write-Host "Playlists merged: $($mergeResults.Merged)" -ForegroundColor Magenta
Write-Host "Duplicate playlists removed: $($mergeResults.Removed)" -ForegroundColor Magenta
Write-Host "Final memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")