<#
.SYNOPSIS
    把当前目录初始化为可多人协作的 Git 仓库（Windows / PowerShell）。

.DESCRIPTION
    干四件事：
      1. git init（默认分支 main）
      2. 写入仓库级配置：换行、长路径、提交模板、pull 用 rebase
      3. 检查提交身份、扫描超大文件与敏感文件
      4. 生成首个提交，可选设置远端

.PARAMETER RemoteUrl
    远端仓库地址，给了就自动 git remote add origin。

.PARAMETER Branch
    主干分支名，默认 main。

.PARAMETER SkipCommit
    只做初始化与配置，不自动提交。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\init-repo.ps1
    powershell -ExecutionPolicy Bypass -File scripts\init-repo.ps1 -RemoteUrl git@github.com:org/repo.git
#>
[CmdletBinding()]
param(
    [string]$RemoteUrl,
    [string]$Branch = 'main',
    [switch]$SkipCommit
)

$ErrorActionPreference = 'Stop'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Say ($m) { Write-Host "    $m" }
function Warn($m) { Write-Host "    !! $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "    xx $m" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 0. 环境
Step '检查 git'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail '未找到 git。请先安装 Git for Windows：https://git-scm.com/download/win ，装完重开终端。'
}
Say (git --version)

$root = (Get-Location).Path
Say "工作目录：$root"

if (-not (Test-Path (Join-Path $root '.gitattributes'))) {
    Warn '当前目录下没有 .gitattributes —— 请确认在仓库根目录（README.md 所在处）执行本脚本。'
    $answer = Read-Host '    仍要继续？(y/N)'
    if ($answer -ne 'y') { Fail '已取消' }
}

# ---------------------------------------------------------------- 1. init
Step "初始化仓库（主干分支 $Branch）"
if (Test-Path (Join-Path $root '.git')) {
    Warn '当前目录已是 git 仓库，跳过 init，仅补齐配置'
} else {
    git init -b $Branch 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        # 老版本 git 不支持 -b
        git init | Out-Null
        git symbolic-ref HEAD "refs/heads/$Branch"
    }
    Say "已初始化"
}

# ---------------------------------------------------------------- 2. 配置
Step '写入仓库级配置'
$pairs = @(
    @('core.autocrlf',       'false'),   # 换行交给 .gitattributes
    @('core.safecrlf',       'warn'),
    @('core.quotepath',      'false'),   # 中文文件名不转义
    @('core.longpaths',      'true'),    # 深目录路径
    @('pull.rebase',         'true'),
    @('fetch.prune',         'true'),
    @('rebase.autoStash',    'true'),
    @('commit.template',     '.gitmessage'),
    @('merge.conflictStyle', 'zdiff3')
)
foreach ($p in $pairs) {
    git config $p[0] $p[1]
    Say ("{0,-22} = {1}" -f $p[0], $p[1])
}

# ---------------------------------------------------------------- 3. 身份
Step '检查提交身份'
$name  = git config user.name
$email = git config user.email
if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($email)) {
    Warn '未配置提交身份，无法生成提交。请先执行（换成你自己的）：'
    Write-Host '        git config --global user.name  "张三"'   -ForegroundColor Gray
    Write-Host '        git config --global user.email "zhangsan@company.com"' -ForegroundColor Gray
    Warn '配好后重新运行本脚本'
    exit 1
}
Say "$name <$email>"

# ---------------------------------------------------------------- 4. 大文件
Step '扫描超大文件（> 20MB）'
$skip = '\\(\.git|node_modules|\.venv|venv|\.codebuddy|dist|build)\\|\.(zip|7z|rar|tar|gz|exe|msi|mp4|mov|onnx|pt|pth|bag|pcd)$'
$big = @(Get-ChildItem -Path $root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $skip -and $_.Length -gt 20MB } |
    Sort-Object Length -Descending)

if ($big.Count -gt 0) {
    Warn "发现 $($big.Count) 个超过 20MB 的文件，逐个确认是否需要入库："
    $big | Select-Object -First 20 | ForEach-Object {
        Say ("{0,8:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName.Substring($root.Length + 1))
    }
    Warn '大文件建议放项目网盘；确需入库请先启用 Git LFS'
} else {
    Say '无超大文件'
}

# ---------------------------------------------------------------- 5. 暂存
Step '暂存文件'
git add -A
$staged = @(git diff --cached --name-only)
Say "已暂存 $($staged.Count) 个文件"

# ---------------------------------------------------------------- 6. 敏感文件
Step '检查敏感文件是否被暂存'
$suspicious = @($staged | Where-Object {
        $_ -match '(^|/)\.env$' -or
        $_ -match '(^|/)\.env\.(?!example)' -or
        $_ -match '\.(pem|key|p12|pfx)$' -or
        $_ -match '(^|/)(secrets|\.aws|\.ssh)/'
    })
if ($suspicious.Count -gt 0) {
    Warn '以下文件疑似含密钥/配置，已被暂存：'
    $suspicious | ForEach-Object { Say $_ }
    Warn '逐个确认，不该入库的执行： git rm --cached <文件>'
} else {
    Say '未发现敏感文件'
}

# ---------------------------------------------------------------- 7. 提交
if ($SkipCommit) {
    Step '已跳过提交（-SkipCommit）'
} elseif ($staged.Count -eq 0) {
    Step '没有需要提交的内容'
} else {
    Step '创建首个提交'
    $msg = @"
chore: 初始化多人协作骨架

- 协作规范：CONTRIBUTING.md、docs/00 ~ docs/03
- 责任人机制：CODEOWNERS
- 工程约束：.gitattributes 统一换行、.gitignore 忽略生成物与敏感文件
- 提交与评审模板：.gitmessage、.github/
- 工具脚本：init-repo、pre-push-check
"@
    git commit -m $msg | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail '提交失败，请检查上面的报错' }
    Say (git log --oneline -1)
}

# ---------------------------------------------------------------- 8. 远端
if ($RemoteUrl) {
    Step '设置远端'
    git remote remove origin 2>$null
    git remote add origin $RemoteUrl
    Say "origin = $RemoteUrl"
}

# ---------------------------------------------------------------- 9. 收尾
Step '完成'
Write-Host @"

    接下来：
      1) 到代码平台新建空仓库（不要勾选初始化 README）
      2) git remote add origin <地址>
         git push -u origin $Branch
      3) 在平台设置里保护 $Branch：禁止直推、要求 PR + 1 人 approve、只允许 squash
      4) 把 CODEOWNERS 里的 @xxx-placeholder 换成真实账号
      5) 去 WorkBuddy 项目里邀请成员，按 docs/00 的清单配好待办与网盘

"@ -ForegroundColor Gray
