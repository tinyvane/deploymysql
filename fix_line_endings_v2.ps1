$content = Get-Content -Path "deploymysql.sh" -Raw
$content = $content -replace "`r`n", "`n"

# Fix the first issue - ensure proper spacing between function definitions
$content = $content -replace "}\n# ", "}\n\n# "

# Fix the second issue - ensure main function has proper closing brace with spacing
$content = $content -replace "}\n\n# 执行主函数", "}\n\n# 执行主函数"

# Ensure the main function call is on a new line after the comment
$content = $content -replace "# 执行主函数\nmain", "# 执行主函数\n\nmain"

Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 