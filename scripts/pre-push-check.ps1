<#
.SYNOPSIS
    推送前自检（Windows / PowerShell 版）：冲突标记、超大文件、疑似密钥、调试残留、提交信息。
    只读检查，不修改文件。有 FAIL 项时退出码为 1。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\pre-push-check.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$fail = $false

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok  ($m) { Write-Host "    OK   $m" -ForegroundColor Green }
function Bad ($m) { Write-Host "    FAIL $m" -ForegroundColor Red; $script:fail = $true }
function Warn($m) { Write-Host "    WARN $m" -ForegroundColor Yellow }

# 待检文件
$hasOrigin = $false
git rev-parse --verify origin/main 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { $hasOrigin = $true }

if ($hasOrigin) {
    $base  = git merge-base HEAD origin/main
    $files = @(git diff --name-only --diff-filter=ACMR "$base...HEAD")
    $scope = '相对 origin/main 的改动'
} else {
    $files = @(git ls-files)
    $scope = '全部已跟踪文件（未找到 origin/main）'
}

if ($files.Count -eq 0) { Write-Host '没有待检查的改动。'; exit 0 }
Write-Host "检查范围：$scope"

$binaryExt = '\.(png|jpg|jpeg|gif|ico|pdf|zip|7z|gz|onnx|pt|pth|bag|pcd|ply|xlsx|docx|pptx|mp4|mov)$'

# ---------------------------------------------------------------- 1. 冲突标记
Step '冲突标记'
$hits = @()
foreach ($f in $files) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    if ($f -match $binaryExt) { continue }
    $m = Select-String -LiteralPath $f -Pattern '^(<<<<<<< |=======$|>>>>>>> )' -ErrorAction SilentlyContinue
    if ($m) { $hits += "$f:$($m[0].LineNumber)" }
}
if ($hits.Count -gt 0) { Bad ("存在未解决的冲突标记：" + ($hits -join ', ')) } else { Ok '无' }

# ---------------------------------------------------------------- 2. 超大文件
Step '文件体积（上限 20MB）'
$big = @()
foreach ($f in $files) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $sz = (Get-Item -LiteralPath $f).Length
    if ($sz -gt 20MB) { $big += ("{0,8:N1} MB  {1}" -f ($sz / 1MB), $f) }
}
if ($big.Count -gt 0) { Bad '以下文件超过 20MB，请改用 Git LFS 或项目网盘：'; $big | ForEach-Object { Write-Host "    $_" } }
else { Ok '无' }

# ---------------------------------------------------------------- 3. 疑似密钥
Step '疑似密钥与凭据'
$patterns = @(
    '-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----',
    'AKID[0-9A-Za-z]{16,}',
    'sk-[A-Za-z0-9]{20,}',
    'ghp_[A-Za-z0-9]{20,}',
    'xox[baprs]-[A-Za-z0-9-]{10,}',
    '(password|passwd|pwd|token|secret|api[_-]?key)\s*[:=]\s*["''][^"'']{8,}'
)
$secrets = @()
foreach ($f in $files) {
    if ($f -match $binaryExt) { continue }
    if ($f -match '\.env\.example$') { continue }
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    foreach ($p in $patterns) {
        $m = Select-String -LiteralPath $f -Pattern $p -ErrorAction SilentlyContinue
        if ($m) { $secrets += "    ${f}:$($m[0].LineNumber)  $($m[0].Line.Trim())"; break }
    }
}
if ($secrets.Count -gt 0) { Bad '发现疑似密钥，请确认后再推：'; $secrets | ForEach-Object { Write-Host $_ } }
else { Ok '无' }

# ---------------------------------------------------------------- 4. 敏感文件入库
Step '敏感文件是否被跟踪'
$trackedBad = @($files | Where-Object { $_ -match '(^|/)\.env$|\.(pem|key|p12|pfx)$|(^|/)(secrets|\.ssh)/' })
if ($trackedBad.Count -gt 0) {
    Bad '以下敏感文件已被 git 跟踪：'
    $trackedBad | ForEach-Object { Write-Host "    $_" }
    Write-Host '    移除： git rm --cached <文件>  →  轮换密钥  →  再考虑清历史'
} else { Ok '无' }

# ---------------------------------------------------------------- 5. 调试残留
Step '调试残留'
$debug = @()
foreach ($f in $files) {
    if ($f -match $binaryExt) { continue }
    if ($f -match '(\.md|lock\.json|lock\.yaml|pnpm-lock\.yaml|package-lock\.json)$') { continue }
    if ($f -match 'scripts/pre-push-check\.') { continue }   # 自检脚本自身含这些关键字
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $m = Select-String -LiteralPath $f -Pattern '(console\.(log|debug)|debugger;|pdb\.set_trace\(\)|breakpoint\(\)|\.only\()' -ErrorAction SilentlyContinue |
         Select-Object -First 3
    if ($m) { $m | ForEach-Object { $debug += "    ${f}:$($_.LineNumber)  $($_.Line.Trim())" } }
}
if ($debug.Count -gt 0) { Warn '发现可能的调试残留（确认后再推）：'; $debug | ForEach-Object { Write-Host $_ } }
else { Ok '无' }

# ---------------------------------------------------------------- 6. 提交信息
Step '最近提交信息格式'
$last = git log -1 --pretty=%s 2>$null
if ([string]::IsNullOrWhiteSpace($last)) {
    Warn '还没有提交'
} elseif ($last -match '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9_/-]+\))?: .+') {
    Ok $last
} else {
    Bad "不符合 <type>(<scope>): <摘要> —— $last"
}

# ---------------------------------------------------------------- 汇总
Write-Host ''
if ($fail) {
    Write-Host '自检未通过，先处理上面的 FAIL 项。' -ForegroundColor Red
    exit 1
}
Write-Host '自检通过，可以推送。' -ForegroundColor Green
