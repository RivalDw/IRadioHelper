# Simple M3U Creator - PowerShell 7+ (Sanitized and Truncated Genre Names)
chcp 65001 | Out-Null
$Host.UI.RawUI.WindowTitle = "Simple M3U Creator - PowerShell 7+"

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

$genreCount = [System.Collections.Concurrent.ConcurrentDictionary[string,int]]::new()
$genreTracks = [System.Collections.Concurrent.ConcurrentDictionary[string,System.Collections.ArrayList]]::new()

"=== Start: $(Get-Date) ===" | Out-File -FilePath $logFile -Encoding UTF8

# Find audio files
$audioExtensions = @(".mp3", ".flac", ".wav", ".m4a", ".aac", ".ogg", ".wma")
$audioFiles = Get-ChildItem -Path $music_path -Recurse | Where-Object { $_.Extension -in $audioExtensions }

Write-Host "Found $($audioFiles.Count) files"
$total_files = $audioFiles.Count
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Function to sanitize file names
function SanitizeFileName {
    param([string]$name)
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($c in $invalidChars) {
        $name = $name.Replace($c,'_')
    }
    return ($name -replace '\s+', ' ').Trim()
}

#Parallel processing with functions inside block
$results = $audioFiles | ForEach-Object -Parallel {
    function Parse-FileName { param([string]$filename)
        if ($filename -notmatch " - ") { return $null }
        $parts = $filename -split " - ", 2
        return @{ Artist = $parts[0].Trim(); Title = $parts[1].Trim() }
    }
	
	#dmmy fnc
    function Get-GenreFromArtist { param([string]$artist)
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

    function Get-GenreFromTags { param([string]$filePath)
        try {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace((Split-Path $filePath))
            $file = $folder.ParseName((Split-Path $filePath -Leaf))
            $g = $folder.GetDetailsOf($file, 16)
            if ([string]::IsNullOrWhiteSpace($g)) { return $null }
            return $g.Trim()
        } catch { return $null }
    }

    $file = $_
    $parsed = Parse-FileName -filename $file.BaseName
    $artist = if ($parsed) { $parsed.Artist } else { "Unknown Artist" }
    $title = if ($parsed) { $parsed.Title } else { $file.BaseName }

    $genre = Get-GenreFromTags -filePath $file.FullName
    if (-not $genre) { $genre = Get-GenreFromArtist -artist $artist }

    [PSCustomObject]@{
        FilePath = $file.FullName
        Artist = $artist
        Title = $title
        Genre = $genre
    }
} -ThrottleLimit 8

# Build main playlist & genre playlists
$mainPlaylistLines = @("#EXTM3U")
foreach ($track in $results) {
    $mainPlaylistLines += "#EXTINF:-1,$($track.Artist) - $($track.Title)"
    $mainPlaylistLines += $track.FilePath

    if (-not $genreCount.ContainsKey($track.Genre)) {
        $genreCount[$track.Genre] = 0
        $genreTracks[$track.Genre] = @()
    }
    $genreCount[$track.Genre]++
    $genreTracks[$track.Genre] += @{ FilePath=$track.FilePath; Artist=$track.Artist; Title=$track.Title }

    if ($track.Genre -ne "Unknown") { $files_with_genre++ }
}

# Write main playlist
$mainPlaylistLines | Out-File -FilePath $main_playlist -Encoding UTF8

# Write genre playlists (sanitize and truncate names)
foreach ($genre in $genreCount.Keys) {
    $count = $genreCount[$genre]
    if ($genre -ne "Unknown" -and $count -gt 10) {

        # Берём только первый жанр, если их несколько через ; | , 
        $genrePlaylistName = ($genre -split '[;|,]').Trim() | Select-Object -First 1
        $genrePlaylistName = SanitizeFileName($genrePlaylistName)

        # Обрезаем имя, чтобы не превышать 50 символов
        if ($genrePlaylistName.Length -gt 50) { $genrePlaylistName = $genrePlaylistName.Substring(0,50) }

        $genrePlaylist = Join-Path $genre_dir "$genrePlaylistName.m3u"
        $lines = @("#EXTM3U")
        foreach ($track in $genreTracks[$genre]) {
            $lines += "#EXTINF:-1,$($track.Artist) - $($track.Title)"
            $lines += $track.FilePath
        }
        $lines | Out-File -FilePath $genrePlaylist -Encoding UTF8
    }
}

# Logging
$stopwatch.Stop()
"" | Out-File -FilePath $logFile -Append
"=== Completed: $(Get-Date) ===" | Out-File -FilePath $logFile -Append
"Execution time: $($stopwatch.Elapsed.ToString())" | Out-File -FilePath $logFile -Append
"Files processed: $total_files" | Out-File -FilePath $logFile -Append
"Files with genre: $files_with_genre" | Out-File -FilePath $logFile -Append
"Files without genre: $($total_files - $files_with_genre)" | Out-File -FilePath $logFile -Append
"Genres found: $($genreCount.Keys.Count)" | Out-File -FilePath $logFile -Append

Write-Host ""
Write-Host "========================================"
Write-Host "COMPLETED!"
Write-Host "Main playlist: $main_playlist"
Write-Host "Genre playlists: $genre_dir\"
Write-Host "Log file: $logFile"
Write-Host "Total files processed: $total_files in $($stopwatch.Elapsed.ToString())"
Write-Host "========================================"
Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
