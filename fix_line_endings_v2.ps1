$content = Get-Content -Path "deploymysql.sh" -Raw
$content = $content -replace "`r`n", "`n"

# Ensure there's a newline between closing braces and function declarations for all functions
$content = $content -replace "}\n# ", "}\n\n# "

# Ensure main function call has a newline after the last function
$content = $content -replace "}\n# 执行主函数\nmain", "}\n\n# 执行主函数\nmain"

Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 