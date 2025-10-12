# Simple M3U Creator - PowerShell 7+ (Improved Genre Detection & Memory Optimized)

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
$Host.UI.RawUI.WindowTitle = "Simple M3U Creator - PowerShell 7+ (Improved Genres)"

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

# Function to normalize genre names
function Normalize-GenreName {
    param([string]$genreName)
    
    $genreMap = @{
        "Pop-Rock" = "Rock"
        "Hard Rock" = "Rock" 
        "Alternative Rock" = "Rock"
        "Classic Rock" = "Rock"
        "Electronic Body Music" = "EBM"
        "Electro Metal" = "Industrial Metal"
        "Neue Deutsche Härte" = "Industrial Metal"
    }
    
    if ($genreMap.ContainsKey($genreName)) {
        return $genreMap[$genreName]
    }
    return $genreName
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
        "ost\+front", "die krupps", "and one", "wumpscut"
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
        "agonoize", "meister", "x\-fusion", "centhron"
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
        "front 242", "nitzer ebb", "die krupps", "a split\-second", "the klinik",
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
        "bloodhound gang", "green day", "blink\-182", "offspring", "rancid",
        "no fx", "bad religion", "the exploited", "sex pistols", "the clash"
    )
    "Grunge" = @(
        "nirvana", "pearl jam", "soundgarden", "alice in chains", "stone temple pilots",
        "mudhoney", "smashing pumpkins", "bush"
    )
    "Hard Rock" = @(
        "ac\/dc", "guns n'roses", "aerosmith", "van halen", "kiss",
        "def leppard", "whitesnake", "scorpions", "deep purple"
    )
    "Hip-Hop" = @(
        "eminem", "50 cent", "dr\.dre", "snoop dogg", "tupac", "notorious b\.i\.g",
        "jay\-z", "nas", "wu\-tang clan", "public enemy"
    )
    "Pop" = @(
        "rihanna", "britney spears", "justin bieber", "taylor swift", "lady gaga",
        "katy perry", "madonna", "michael jackson", "beyonce"
    )
    "Electronic" = @(
        "daft punk", "chemical brothers", "prodigy", "fatboy slim", "aphex twin",
        "kraftwerk", "jean\-michel jarre", "tangerine dream"
    )
    # Russian artists mapping
    "Russian Pop" = @(
        "серега", "пират", "серега пират", "серегапират", "тимати", "баста", "грибы",
        "монеточка", "иван дорн", "лсп", "элджей", "макс корж", "zivert", "мотивация",
        "маршал", "каспийский груз", "полигамность", "раут"
    )
    "Russian Rock" = @(
        "ддт", "кино", "наутилус помпилиус", "ария", "агата кристи",
        "би\-2", "сплин", "звери", "мумий тролль", "чайф", "алиса",
        "король и шут", "аукцыон", "наив", "ночные снайперы"
    )
    "Russian Hip-Hop" = @(
        "каста", "центр", "психея", "трэш сцена", "антоха мс", "баста",
        "смоки мо", "грот", "алексей вишня", "noize mc"
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
            # Import the genre mapping and functions
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
                $a = $artist.ToLower().Trim()
                
                # Сначала проверяем точные совпадения (для русских артистов)
                foreach ($genre in $GenreMapping.Keys) {
                    foreach ($pattern in $GenreMapping[$genre]) {
                        if ($a -eq $pattern) {
                            return $genre
                        }
                    }
                }
                
                # Затем проверяем частичные совпадения
                foreach ($genre in $GenreMapping.Keys) {
                    foreach ($pattern in $GenreMapping[$genre]) {
                        if ($a -match $pattern) {
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
                    
                    $cleanGenre = ($g -split '[;|,]')[0].Trim()
                    
                    # Игнорировать слишком общие или некорректные жанры
                    $ignoreGenres = @("Other", "Various", "Unknown", "Misc")
                    if ($ignoreGenres -contains $cleanGenre) {
                        return $null
                    }
                    
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

            # Приоритет: артист → теги
            $genreFromArtist = Get-GenreFromArtist -artist $artist
            if ($genreFromArtist -ne "Unknown") {
                $genre = $genreFromArtist  # Приоритет у определения по артисту
            } else {
                # Только если по артисту не определилось, используем теги
                $genre = Get-GenreFromTags -filePath $file.FullName
                if (-not $genre -or [string]::IsNullOrWhiteSpace($genre)) {
                    $genre = "Unknown"
                }
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

# Function to merge similar playlists (improved - объединяет плейлисты где один является подмножеством другого)
function Merge-SimilarPlaylists {
    param([string]$playlistsDir)
    
    Write-Host "Умное объединение плейлистов..." -ForegroundColor Yellow
    
    $allPlaylists = Get-ChildItem -Path $playlistsDir -Filter "*.m3u" -File
    $playlistInfo = @()
    
    # Собираем информацию о всех плейлистах
    foreach ($playlist in $allPlaylists) {
        $baseName = $playlist.BaseName
        $genres = $baseName -split '_' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object
        
        # Создаем HashSet правильно
        $genreSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($genre in $genres) {
            $null = $genreSet.Add($genre)
        }
        
        $playlistInfo += @{
            Path = $playlist.FullName
            Name = $playlist.Name
            BaseName = $baseName
            Genres = $genres
            GenreSet = $genreSet
            GenreKey = ($genres -join '_').ToLower()
        }
    }
    
    $mergedCount = 0
    $removedCount = 0
    $processedPlaylists = @{}
    
    # Группируем плейлисты по основным жанрам
    Write-Host "Анализ плейлистов для объединения..." -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $playlistInfo.Count; $i++) {
        if ($processedPlaylists.ContainsKey($playlistInfo[$i].Path)) { continue }
        
        $current = $playlistInfo[$i]
        $similarPlaylists = @($current.Path)
        
        # Ищем плейлисты, которые являются подмножествами или надмножествами текущего
        for ($j = $i + 1; $j -lt $playlistInfo.Count; $j++) {
            if ($processedPlaylists.ContainsKey($playlistInfo[$j].Path)) { continue }
            
            $other = $playlistInfo[$j]
            
            # Проверяем, является ли один плейлист подмножеством другого
            $isCurrentSubsetOfOther = $true
            foreach ($genre in $current.GenreSet) {
                if (-not $other.GenreSet.Contains($genre)) {
                    $isCurrentSubsetOfOther = $false
                    break
                }
            }
            
            $isOtherSubsetOfCurrent = $true
            foreach ($genre in $other.GenreSet) {
                if (-not $current.GenreSet.Contains($genre)) {
                    $isOtherSubsetOfCurrent = $false
                    break
                }
            }
            
            $isSubset = $isCurrentSubsetOfOther -or $isOtherSubsetOfCurrent
            
            if ($isSubset) {
                $similarPlaylists += $other.Path
                $processedPlaylists[$other.Path] = $true
            }
        }
        
        if ($similarPlaylists.Count -gt 1) {
            Write-Host "Объединение $($similarPlaylists.Count) плейлистов: $($current.BaseName) и связанные" -ForegroundColor Cyan
            
            # Находим самый полный набор жанров (с наибольшим количеством жанров)
            $maxGenres = $current.Genres
            foreach ($playlistPath in $similarPlaylists) {
                $pl = $playlistInfo | Where-Object { $_.Path -eq $playlistPath }
                if ($pl.Genres.Count -gt $maxGenres.Count) {
                    $maxGenres = $pl.Genres
                }
            }
            
            # Use HashSet for track deduplication
            $allTracks = @{}
            
            foreach ($playlistFile in $similarPlaylists) {
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
            
            # Create merged playlist with the most complete genre set
            if ($allTracks.Count -gt 0) {
                $newName = ($maxGenres -join '_') + ".m3u"
                $newPath = Join-Path $playlistsDir $newName
                
                # Stream write to file
                $stream = [System.IO.StreamWriter]::new($newPath, $false, [System.Text.Encoding]::UTF8)
                $stream.WriteLine("#EXTM3U")
                
                foreach ($trackPath in $allTracks.Keys) {
                    $stream.WriteLine($allTracks[$trackPath])
                    $stream.WriteLine($trackPath)
                }
                $stream.Close()
                
                # Remove old playlists
                foreach ($oldPlaylist in $similarPlaylists) {
                    if ($oldPlaylist -ne $newPath) {
                        Remove-Item -Path $oldPlaylist -Force
                        $removedCount++
                    }
                }
                
                $mergedCount++
                Write-Host "  -> Создан объединенный плейлист: $newName ($($allTracks.Count) треков)" -ForegroundColor Green
            }
            
            $allTracks.Clear()
        }
        
        $processedPlaylists[$current.Path] = $true
    }
    
    Write-Host "Объединение завершено: $mergedCount объединенных плейлистов, $removedCount старых плейлистов удалено" -ForegroundColor Green
    return @{ Merged = $mergedCount; Removed = $removedCount }
}

# Main processing
Write-Host "Starting processing with improved genre detection..." -ForegroundColor Yellow
Write-Host "Initial memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Gray

# Process files
$results = Process-FileBatch -Files $audioFiles -BatchSize 200

Write-Host "Processing completed. Memory usage: $(Get-MemoryUsage) MB" -ForegroundColor Green
Write-Host "Building playlists..." -ForegroundColor Yellow

# Calculate adaptive minimum tracks for playlist
$minTracksForPlaylist = [math]::Max(3, [math]::Min(10, [int]($total_files / 500)))
Write-Host "Минимальное количество треков для плейлиста: $minTracksForPlaylist" -ForegroundColor Cyan

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

    # Normalize genre name before counting
    $normalizedGenre = Normalize-GenreName($track.Genre)

    # Build genre collections
    if (-not $genreCount.ContainsKey($normalizedGenre)) {
        $genreCount[$normalizedGenre] = 0
        $genreTracks[$normalizedGenre] = [System.Collections.Generic.List[object]]::new()
    }
    $genreCount[$normalizedGenre]++
    $genreTracks[$normalizedGenre].Add(@{ FilePath=$track.FilePath; Artist=$track.Artist; Title=$track.Title })

    if ($normalizedGenre -ne "Unknown") { $files_with_genre++ }
}

$mainStream.Close()
Show-Progress -Activity "Building main playlist" -Completed

# Write genre playlists with streaming
Write-Host "Writing genre playlists..." -ForegroundColor Yellow
$genreKeys = @($genreCount.Keys)
$currentGenre = 0

# Log found genres
Write-Host "Found genres: $($genreKeys -join ', ')" -ForegroundColor Cyan

foreach ($genre in $genreKeys) {
    $currentGenre++
    $count = $genreCount[$genre]
    
    Show-Progress -Activity "Writing genre playlists" -Status "Processing $genre ($count tracks)" -Current $currentGenre -Total $genreKeys.Count
    
    if ($genre -ne "Unknown" -and $count -ge $minTracksForPlaylist) {
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

# Logging and statistics
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

# Top genres statistics
Write-Host "`nТоп жанров:" -ForegroundColor Cyan
$genreCount.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value) треков" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "COMPLETED! (Improved Genre Detection)" -ForegroundColor Green
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