# PowerShell脚本用于全面修复deploymysql.sh文件中的括号和换行问题
# 作者：Claude
# 日期：2024-03-15

$content = Get-Content -Path "deploymysql.sh" -Raw

# 1. 确保花括号和函数名之间有正确的空格
$content = $content -replace '(\w+\(\))\s*{', '$1 {'

# 2. 确保函数之间有正确的空行 - 函数结束后应有空行
$content = $content -replace '}\s*#', '}\n\n#'

# 3. 确保if语句的花括号格式正确
$content = $content -replace 'if\s*\[(.*?)\]\s*;?\s*then\s*{', 'if [ $1 ]; then'
$content = $content -replace 'if\s*\[(.*?)\]\s*;?\s*then([^{])', 'if [ $1 ]; then$2'

# 4. 确保else语句的花括号格式正确
$content = $content -replace 'else\s*{', 'else'

# 5. 确保fi后面有正确的空行
$content = $content -replace 'fi\s*}\s*', 'fi\n}'

# 6. 确保文件末尾有空行，但不要过多
while ($content.EndsWith("`n`n`n")) {
    $content = $content.Substring(0, $content.Length - 1)
}
if (-not $content.EndsWith("`n`n")) {
    $content = $content.TrimEnd("`n") + "`n`n"
}

# 7. 确保main调用后有换行符
$content = $content -replace 'main\s*$', "main`n"

# 保存修改后的内容到新文件，以防万一
$content | Set-Content -Path "deploymysql_fixed_v2.sh" -NoNewline
# 也同时更新原始文件
$content | Set-Content -Path "deploymysql.sh" -NoNewline

Write-Host "文件已全面修复并保存为deploymysql_fixed_v2.sh，同时更新了原始文件。" 