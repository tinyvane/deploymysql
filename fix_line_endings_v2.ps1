$content = Get-Content -Path "deploymysql.sh" -Raw
$content = $content -replace "`r`n", "`n"

# Fix the first issue - ensure proper spacing between function definitions
$content = $content -replace "}\n# ", "}\n\n# "

# Specific fix for secure_mysql function
$content = $content -replace "    fi\n}\n\n# 配置MySQL", "    fi\n}\n\n# 配置MySQL"

# Fix for specific syntax issue in secure_mysql (duplicate close brace)
$content = $content -replace "return 0\n    }\n}", "return 0\n}"

# Fix the second issue - ensure main function has proper closing brace with spacing
$content = $content -replace "}\n\n# 执行主函数", "}\n\n# 执行主函数"

# Ensure the main function call is on a new line after the comment
$content = $content -replace "# 执行主函数\nmain", "# 执行主函数\n\nmain"

Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 