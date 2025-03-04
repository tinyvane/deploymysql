$content = Get-Content -Path "deploymysql.sh" -Raw
$content = $content -replace "`r`n", "`n"

# Ensure there's a newline between closing braces and function declarations
$content = $content -replace "}\n# 显示连接信息", "}\n\n# 显示连接信息"

Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 