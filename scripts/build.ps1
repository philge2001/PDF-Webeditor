# Baut die Webapp nach dist\ – Gegenstück zu scripts/build.sh für Windows (PowerShell 5.1).
#
# Aufruf (PowerShell, im Projektordner):
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1           # Release-Build
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Dev      # schneller gebaut, größer
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1 -Serve    # bauen und lokal starten
#
# Einmalig vorher:
#   rustup target add wasm32-unknown-unknown
#   cargo install wasm-bindgen-cli --version 0.2.129 --locked
param(
    [switch]$Dev,
    [switch]$Serve,
    [int]$Port = 8080
)
$ErrorActionPreference = "Stop"

# Externes Programm starten; Fehler nur über den Exit-Code. (Windows PowerShell 5.1 würde sonst
# jede Ausgabe auf stderr, z. B. Fortschrittsmeldungen von cargo, als Fehler werten und abbrechen.)
function Invoke-Tool([string]$Exe, [string[]]$ArgList) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Exe @ArgList 2>&1 | ForEach-Object { Write-Host $_ }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "$Exe $($ArgList -join ' ') fehlgeschlagen (Exit-Code $code)" }
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

# --- wasm-bindgen-cli muss exakt zur Version in Cargo.toml passen ---
$Want = (Select-String -Path "Cargo.toml" -Pattern 'wasm-bindgen = "=([0-9.]+)"').Matches[0].Groups[1].Value
$Have = ""
if (Get-Command "wasm-bindgen" -ErrorAction SilentlyContinue) {
    $Have = ((& wasm-bindgen --version) -split " ")[1]
}
if ($Have -ne $Want) {
    Write-Host "wasm-bindgen-cli $Want benötigt (gefunden: $(if ($Have) { $Have } else { 'keine' }))."
    Write-Host "Installieren: cargo install wasm-bindgen-cli --version $Want --locked"
    exit 1
}

# --- PDFium als WebAssembly (pdfium-lib), wie scripts/fetch-pdfium.sh ---
$PdfiumVersion = "7902"
$Vendor = Join-Path $Root "vendor\pdfium"
$VersionFile = Join-Path $Vendor "VERSION"
if ((Test-Path (Join-Path $Vendor "pdfium.wasm")) -and (Test-Path $VersionFile) -and
    ((Get-Content $VersionFile -Raw).Trim() -eq $PdfiumVersion)) {
    Write-Host "PDFium $PdfiumVersion liegt schon in $Vendor"
} else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfwebeditor-pdfium-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $Tmp | Out-Null
    try {
        # curl.exe und tar.exe sind seit Windows 10 (1803) eingebaut.
        $Url = "https://github.com/paulocoutinhox/pdfium-lib/releases/download/$PdfiumVersion/wasm.tgz"
        Write-Host "Lade $Url"
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Tmp "wasm.tgz"), $Url)
        Invoke-Tool "tar.exe" @("-xzf", (Join-Path $Tmp "wasm.tgz"), "-C", $Tmp)

        if (Test-Path $Vendor) { Remove-Item -Recurse -Force $Vendor }
        $Lic = Join-Path $Vendor "licenses"
        New-Item -ItemType Directory -Force $Lic | Out-Null
        Copy-Item (Join-Path $Tmp "release\node\pdfium.js") $Vendor
        Copy-Item (Join-Path $Tmp "release\node\pdfium.wasm") $Vendor

        # Lizenztexte: pdfium-lib (MIT) und PDFium samt Drittbibliotheken (aus dem bblanchon-Paket).
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Lic "pdfium-lib.md"),
            "https://raw.githubusercontent.com/paulocoutinhox/pdfium-lib/master/LICENSE.md")
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Tmp "bb.tgz"),
            "https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7881/pdfium-wasm.tgz")
        Invoke-Tool "tar.exe" @("-xzf", (Join-Path $Tmp "bb.tgz"), "-C", $Tmp, "licenses")
        Copy-Item (Join-Path $Tmp "licenses\*") $Lic

        Set-Content -Path $VersionFile -Value $PdfiumVersion -Encoding ASCII
        Write-Host "PDFium $PdfiumVersion nach $Vendor geladen"
    } finally {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    }
}

# --- Liberation-Schriften (werden im Browser nachgeladen), wie scripts/fetch-fonts.sh ---
$Rev = (Select-String -Path "Cargo.toml" -Pattern 'PDF-Tool", rev = "([0-9a-f]+)"').Matches[0].Groups[1].Value
$Fonts = Join-Path $Root "vendor\fonts"
$FontRevFile = Join-Path $Fonts "REV"
if ((Test-Path $FontRevFile) -and ((Get-Content $FontRevFile -Raw).Trim() -eq $Rev)) {
    Write-Host "Schriften (PDF-Tool $Rev) liegen schon in $Fonts"
} else {
    if (Test-Path $Fonts) { Remove-Item -Recurse -Force $Fonts }
    New-Item -ItemType Directory -Force $Fonts | Out-Null
    $Base = "https://raw.githubusercontent.com/philge2001/PDF-Tool/$Rev/assets/fonts"
    foreach ($n in @("Sans", "Serif", "Mono")) {
        foreach ($st in @("Regular", "Bold", "Italic", "BoldItalic")) {
            $f = "Liberation$n-$st.ttf"
            Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts $f), "$Base/liberation/$f")
        }
    }
    Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts "COPYRIGHT-Liberation.txt"), "$Base/liberation/COPYRIGHT")
    Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Fonts "OFL.txt"), "$Base/OFL.txt")
    Set-Content -Path $FontRevFile -Value $Rev -Encoding ASCII
    Write-Host "Liberation-Schriften (PDF-Tool $Rev) nach $Fonts geladen"
}

# --- Oberflächenschrift Inter (wird im Browser nachgeladen), wie scripts/fetch-ui-font.sh ---
$InterVersion = "4.1"
$InterSha = "9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e"
$UiFont = Join-Path $Root "vendor\ui-font"
$UiFontStamp = Join-Path $UiFont "VERSION"
if ((Test-Path $UiFontStamp) -and ((Get-Content $UiFontStamp -Raw).Trim() -eq $InterVersion)) {
    Write-Host "Inter $InterVersion liegt schon in $UiFont"
} else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfwebeditor-inter-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $Tmp | Out-Null
    try {
        $Zip = Join-Path $Tmp "inter.zip"
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", $Zip,
            "https://github.com/rsms/inter/releases/download/v$InterVersion/Inter-$InterVersion.zip")
        if ((Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower() -ne $InterSha) { throw "Prüfsumme von Inter $InterVersion stimmt nicht" }
        Expand-Archive -Path $Zip -DestinationPath (Join-Path $Tmp "x")
        if (Test-Path $UiFont) { Remove-Item -Recurse -Force $UiFont }
        New-Item -ItemType Directory -Force $UiFont | Out-Null
        # Nur der normale Schnitt: egui kennt keine Schriftstärken (fett = hellere Farbe).
        Copy-Item (Join-Path $Tmp "x\extras\ttf\Inter-Regular.ttf") $UiFont
        Copy-Item (Join-Path $Tmp "x\LICENSE.txt") (Join-Path $UiFont "OFL-Inter.txt")
        Set-Content -Path $UiFontStamp -Value $InterVersion -Encoding ASCII
        Write-Host "Inter $InterVersion nach $UiFont geladen"
    } finally {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    }
}

# --- Texterkennung: tesseract.js + Sprachdaten (erst bei Bedarf geladen), wie scripts/fetch-tesseract.sh ---
$TessVersion = "7.0.0"
$TessSha = @{
    "tesseract.js"      = "exPBkd+z+wM1BuMkx/Bjv43OeLBxhL5kKWsz/9JY+DXcXdiBjiAch0V49QR3oAJqCaL5qURE0vx9Eo+G5YE7mA=="
    "tesseract.js-core" = "WnNH518NzmbSq9zgTPeoF8c+xmilS8rFIl1YKbk/ptuuc7p6cLNELNuPAzcmsYw450ca6bLa8j3t0VAtq435Vw=="
}
$Ocr = Join-Path $Root "vendor\ocr"
$OcrStampFile = Join-Path $Ocr "STAMP"
$OcrStamp = "$TessVersion $Rev"
if ((Test-Path $OcrStampFile) -and ((Get-Content $OcrStampFile -Raw).Trim() -eq $OcrStamp)) {
    Write-Host "Texterkennung (tesseract.js $TessVersion) liegt schon in $Ocr"
} else {
    $Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfwebeditor-ocr-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $Tmp | Out-Null
    try {
        foreach ($pkg in @("tesseract.js", "tesseract.js-core")) {
            $Tgz = Join-Path $Tmp "$pkg.tgz"
            Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", $Tgz,
                "https://registry.npmjs.org/$pkg/-/$pkg-$TessVersion.tgz")
            # Prüfsumme wie in der npm-Registry (SHA-512, Base64).
            $Hex = (Get-FileHash -Algorithm SHA512 $Tgz).Hash
            $Bytes = [byte[]]::new($Hex.Length / 2)
            for ($i = 0; $i -lt $Bytes.Length; $i++) { $Bytes[$i] = [Convert]::ToByte($Hex.Substring(2 * $i, 2), 16) }
            if ([Convert]::ToBase64String($Bytes) -ne $TessSha[$pkg]) { throw "Prüfsumme von $pkg $TessVersion stimmt nicht" }
            $Out = Join-Path $Tmp $pkg
            New-Item -ItemType Directory -Force $Out | Out-Null
            Invoke-Tool "tar.exe" @("-xzf", $Tgz, "-C", $Out)
        }
        if (Test-Path $Ocr) { Remove-Item -Recurse -Force $Ocr }
        foreach ($d in @("core", "lang", "licenses")) { New-Item -ItemType Directory -Force (Join-Path $Ocr $d) | Out-Null }
        $Js = Join-Path $Tmp "tesseract.js\package"
        $Core = Join-Path $Tmp "tesseract.js-core\package"
        Copy-Item (Join-Path $Js "dist\tesseract.min.js") $Ocr
        Copy-Item (Join-Path $Js "dist\worker.min.js") $Ocr
        foreach ($v in @("lstm", "simd-lstm", "relaxedsimd-lstm")) {
            Copy-Item (Join-Path $Core "tesseract-core-$v.wasm.js") (Join-Path $Ocr "core")
        }
        Copy-Item (Join-Path $Js "LICENSE.md") (Join-Path $Ocr "licenses\tesseract.js.md")
        Copy-Item (Join-Path $Core "LICENSE") (Join-Path $Ocr "licenses\tesseract.js-core.txt")
        # Sprachdaten aus PDF-Tool (dieselben wie in der Desktop-App), gzip-komprimiert für tesseract.js.
        $Base = "https://raw.githubusercontent.com/philge2001/PDF-Tool/$Rev/assets/tessdata"
        foreach ($l in @("deu", "eng")) {
            $Raw = Join-Path $Tmp "$l.traineddata"
            Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", $Raw, "$Base/$l.traineddata")
            $In = [System.IO.File]::OpenRead($Raw)
            $Dst = [System.IO.File]::Create((Join-Path $Ocr "lang\$l.traineddata.gz"))
            $Gz = New-Object System.IO.Compression.GZipStream($Dst, [System.IO.Compression.CompressionLevel]::Optimal)
            try { $In.CopyTo($Gz) } finally { $Gz.Dispose(); $Dst.Dispose(); $In.Dispose() }
        }
        Invoke-Tool "curl.exe" @("-fsSL", "--retry", "3", "-o", (Join-Path $Ocr "licenses\tessdata.txt"), "$Base/LICENSE")
        Set-Content -Path $OcrStampFile -Value $OcrStamp -Encoding ASCII
        Write-Host "Texterkennung (tesseract.js $TessVersion) nach $Ocr geladen"
    } finally {
        Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    }
}

# --- Rust → WebAssembly ---
$BuildProfile = if ($Dev) { "debug" } else { "release" }
$CargoArgs = @("build", "--target", "wasm32-unknown-unknown")
if (-not $Dev) { $CargoArgs += "--release" }
Invoke-Tool "cargo" $CargoArgs

# --- dist\ zusammenstellen ---
$Dist = Join-Path $Root "dist"
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory -Force (Join-Path $Dist "pkg") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $Dist "pdfium") | Out-Null
$Wasm = Join-Path $Root "target\wasm32-unknown-unknown\$BuildProfile\pdf_webeditor.wasm"
Invoke-Tool "wasm-bindgen" @("--target", "web", "--no-typescript", "--out-dir", (Join-Path $Dist "pkg"), $Wasm)
# Optional (Release): wasm-opt aus binaryen verkleinert das WebAssembly um rund ein Drittel.
if (-not $Dev -and (Get-Command "wasm-opt" -ErrorAction SilentlyContinue)) {
    $Opt = Join-Path $Dist "pkg\pdf_webeditor_bg.wasm"
    Write-Host "wasm-opt -Oz …"
    Invoke-Tool "wasm-opt" @("-Oz", "--enable-bulk-memory", "--enable-nontrapping-float-to-int", "--enable-sign-ext",
        "--enable-mutable-globals", "--enable-reference-types", "--enable-multivalue", $Opt, "-o", $Opt)
}
# Build-Kennung (gepinnter PDF-Tool-Stand + Uhrzeit) gegen veraltete Dateien im Browser-Cache.
$Build = $Rev.Substring(0, 7) + "-" + (Get-Date -Format "yyyyMMddHHmmss")
$Html = [System.IO.File]::ReadAllText((Join-Path $Root "web\index.html")).Replace("__BUILD__", $Build)
[System.IO.File]::WriteAllText((Join-Path $Dist "index.html"), $Html, (New-Object System.Text.UTF8Encoding $false))
Copy-Item (Join-Path $Vendor "pdfium.js") (Join-Path $Dist "pdfium")
Copy-Item (Join-Path $Vendor "pdfium.wasm") (Join-Path $Dist "pdfium")
Copy-Item -Recurse (Join-Path $Vendor "licenses") (Join-Path $Dist "pdfium")
New-Item -ItemType Directory -Force (Join-Path $Dist "fonts") | Out-Null
Copy-Item (Join-Path $Fonts "*.ttf") (Join-Path $Dist "fonts")
Copy-Item (Join-Path $Fonts "*.txt") (Join-Path $Dist "fonts")
New-Item -ItemType Directory -Force (Join-Path $Dist "fonts\ui") | Out-Null
Copy-Item (Join-Path $UiFont "Inter-Regular.ttf") (Join-Path $Dist "fonts\ui")
Copy-Item (Join-Path $UiFont "OFL-Inter.txt") (Join-Path $Dist "fonts\ui")
New-Item -ItemType Directory -Force (Join-Path $Dist "ocr") | Out-Null
foreach ($f in @("tesseract.min.js", "worker.min.js", "core", "lang", "licenses")) {
    Copy-Item -Recurse (Join-Path $Ocr $f) (Join-Path $Dist "ocr")
}

$SizeMb = [math]::Round(((Get-ChildItem -Recurse $Dist | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
Write-Host "Build $Build"
Write-Host "Fertig: dist\ ($SizeMb MB)"

# --- optional: lokal starten (Python: „python“ oder der Launcher „py“) ---
if ($Serve) {
    $Python = @("python", "py", "python3") | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $Python) {
        Write-Host "Kein Python gefunden. dist\ mit einem beliebigen Webserver ausliefern, z. B.:"
        Write-Host "  npx --yes http-server dist -p $Port"
        exit 1
    }
    Write-Host "Webeditor läuft auf http://localhost:$Port  (Beenden mit Strg+C)"
    & $Python -m http.server $Port --directory $Dist
}
