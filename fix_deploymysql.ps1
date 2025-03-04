# PowerShell脚本用于修复deploymysql.sh文件中的括号问题
# 作者：Claude
# 日期：2024-03-15

$content = Get-Content -Path "deploymysql.sh" -Raw

# 确保文件末尾有空行
if (-not $content.EndsWith("`n")) {
    $content += "`n"
}

# 确保main行后有换行符
$content = $content -replace "main$", "main`n"

# 保存修改后的内容
$content | Set-Content -Path "deploymysql.sh" -NoNewline

Write-Host "文件已修复，添加了必要的换行符。" 