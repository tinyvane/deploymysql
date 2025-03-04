$content = [System.IO.File]::ReadAllText("deploymysql.sh")
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText("deploymysql.sh", $content) 