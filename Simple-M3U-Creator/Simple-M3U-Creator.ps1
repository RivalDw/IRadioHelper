# Simple M3U Creator - PowerShell 7+ (Expanded Genre Detection & Memory Optimized)

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
$Host.UI.RawUI.WindowTitle = "Simple M3U Creator - PowerShell 7+ (Expanded Genres)"

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

# Expanded genre mapping with more artists and genres
$GenreMapping = @{
    # Industrial Metal and related genres
    "Industrial Metal" = @(
        "oomph", "rammstein", "megaherz", "eisbrecher", "kmfdm", "ministry", 
        "nine inch nails", "korn", "rob zombie", "white zombie", "static-x",
        "fear factory", "godflesh", "ministry", "pig", "killing joke"
    )
    "Neue Deutsche Härte" = @(
        "rammstein", "oomph", "megaherz", "eisbrecher", "unheilig", "stahlmann",
        "ost+front", "die krupps", "and one", "wumpscut"
    )
    "Gothic Metal" = @(
        "lacrimosa", "lacuna coil", "within temptation", "nightwish", "evanescence",
        "the gathering", "theatre of tragedy", "tristania", "sirenia", "leaves' eyes",
        "after forever", "epica", "within temptation"
    )
    "EBM" = @(
        "front 242", "front line assembly", "nitzer ebb", "wumpscut", "vnv nation",
        "and one", "assemblage 23", "covenant", "combichrist", "suicide commando"
    )
    "Darkwave" = @(
        "clan of xymox", "the cure", "bauhaus", "sisters of mercy", "siouxsie and the banshees",
        "depeche mode", "cocteau twins", "this mortal coil", "dead can dance"
    )
    "Dark Electro" = @(
        "wumpscut", "hocico", "suicide commando", "combichrist", "grendel",
        "agonoize", "meister", "x-fusion", "centhron"
    )
    "Heavy Metal" = @(
        "metallica", "iron maiden", "judas priest", "black sabbath", "ozzy osbourne",
        "dio", "motorhead", "manowar", "saxon", "dokken"
    )
    "Industrial Rock" = @(
        "nine inch nails", "filter", "stabbing westward", "marylin manson", "prick",
        "pigface", "16volt", "acumen nation"
    )
    "Electro Metal" = @(
        "celldweller", "blue stahli", "the algorithm", "iggorrr", "rabbeat",
        "mindless self indulgence"
    )
    "Electronic Body Music" = @(
        "front 242", "nitzer ebb", "die krupps", "a split-second", "the klinik",
        "skinny puppy", "cabaret voltaire"
    )
    # Other existing genres
    "Alternative Metal" = @(
        "slipknot", "system of a down", "deftones", "tool", "korn",
        "mudvayne", "coal chamber", "kittie", "soad"
    )
    "Extreme Metal" = @(
        "cannibal corpse", "marduk", "darkthrone", "mayhem", "emperor",
        "immortal", "behemoth", "dimmu borgir", "cradle of filth"
    )
    "Punk Rock" = @(
        "bloodhound gang", "green day", "blink.182", "offspring", "rancid",
        "no fx", "bad religion", "the exploited", "sex pistols", "the clash"
    )
    "Grunge" = @(
        "nirvana", "pearl jam", "soundgarden", "alice in chains", "stone temple pilots",
        "mudhoney", "smashing pumpkins", "bush"
    )
    "Hard Rock" = @(
        "ac.dc", "guns n.roses", "aerosmith", "van halen", "kiss",
        "def leppard", "whitesnake", "scorpions", "deep purple"
    )
    "Hip-Hop" = @(
        "eminem", "50 cent", "dr.dre", "snoop dogg", "tupac", "notorious b.i.g",
        "jay-z", "nas", "wu-tang clan", "public enemy"
    )
    "Pop" = @(
        "rihanna", "britney spears", "justin bieber", "taylor swift", "lady gaga",
        "katy perry", "madonna", "michael jackson", "beyonce"
    )
    "Electronic" = @(
        "daft punk", "chemical brothers", "prodigy", "fatboy slim", "aphex twin",
        "kraftwerk", "jean-michel jarre", "tangerine dream"
    )
}

# Function to process files in batches
function Process-FileBatch {
    param(
        [array]$Files,
        [int]$BatchSize = 200
    )
    
    $results = [System.Collections.Generic.List[object]]::new()
    $batchCount = [math]::Ceiling($Files.Count / $BatchSize)
    
    for ($i = 0; $i -lt $batchCount; $i++) {
        $startIndex = $i * $BatchSize
        $endIndex = [math]::Min($startIndex + $BatchSize - 1, $Files.Count - 1)
        $batchFiles = $Files[$startIndex..$endIndex]
        
        Write-Host "Processing batch $($i + 1)/$batchCount (Memory: $(Get-MemoryUsage) MB)" -ForegroundColor Gray
        
        $batchResults = $batchFiles | ForEach-Object -Parallel {
            # Import the genre mapping
            $GenreMapping = $using:GenreMapping

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
                
                # Check each genre category
                foreach ($genre in $GenreMapping.Keys) {
                    foreach ($pattern in $GenreMapping[$genre]) {
                        if ($a -match [regex]::Escape($pattern)) {
                            return $genre
                        }
                    }
                }
                
                return "Unknown"
            }

            function Get-GenreFromTags { 
                param([string]$filePath)
                try {
                    $shell = New-Object -ComObject Shell.Application
                    $folder = $shell.Namespace((Split-Path $filePath))
                    $file = $folder.ParseName((Split-Path $filePath -Leaf))
                    $g = $folder.GetDetailsOf($file, 16)  # Genre property
                    if ([string]::IsNullOrWhiteSpace($g)) { return $null }
                    
                    # Clean up genre tag - take first genre if multiple
                    $cleanGenre = ($g -split '[;|,]')[0].Trim()
                    return $cleanGenre
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
            
            # If no genre from tags, try to determine from artist
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
        } -ThrottleLimit 4
        
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

# Main processing
Write-Host "Starting processing with expanded genre detection..." -ForegroundColor Yellow
Write-Host "Initial memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Gray

# Process files
$results = Process-FileBatch -Files $audioFiles -BatchSize 200

Write-Host "Processing completed. Memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Green
Write-Host "Building playlists..." -ForegroundColor Yellow

# Build main playlist with streaming
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

# Log found genres for debugging
Write-Host "Found genres: $($genreKeys -join ', ')" -ForegroundColor Cyan

foreach ($genre in $genreKeys) {
    $currentGenre++
    $count = $genreCount[$genre]
    
    Show-Progress -Activity "Writing genre playlists" -Status "Processing $genre ($count tracks)" -Current $currentGenre -Total $genreKeys.Count
    
    if ($genre -ne "Unknown" -and $count -gt 5) {  # Reduced threshold to 5 tracks
        $genrePlaylistName = SanitizeFileName($genre)
        
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
        
        Write-Host "  -> Created playlist: $genrePlaylistName ($count tracks)" -ForegroundColor Green
    }
}

Show-Progress -Activity "Writing genre playlists" -Completed

# Clean up
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
"Genres found: $($genreKeys.Count)" | Out-File -FilePath $logFile -Append
"Playlists merged: $($mergeResults.Merged)" | Out-File -FilePath $logFile -Append
"Playlists removed: $($mergeResults.Removed)" | Out-File -FilePath $logFile -Append
"Peak memory usage: $(Get-MemoryUsage) MB" | Out-File -FilePath $logFile -Append

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "COMPLETED! (Expanded Genre Detection)" -ForegroundColor Green
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