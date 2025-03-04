$content = Get-Content -Path "deploymysql.sh" -Raw
$content = $content -replace "`r`n", "`n"
Set-Content -Path "deploymysql.sh" -Value $content -NoNewline 