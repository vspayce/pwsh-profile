# Alias: title
function Set-WindowTitle {
    <#
    .SYNOPSIS
        Sets the console window/tab title (the prompt resets it when you change folders).
    .EXAMPLE
        title PROD - be careful
    #>
    param([Parameter(ValueFromRemainingArguments)][string[]]$Title)
    $Host.UI.RawUI.WindowTitle = $Title -join ' '
}
