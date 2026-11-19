# PSReadLine: history search, predictions, menu completion.
# Only runs in interactive hosts where PSReadLine is loaded.

$__psrl = Get-Module -Name PSReadLine
if ($__psrl) {
    $__opts = @{
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        MaximumHistoryCount           = 10000
        BellStyle                     = 'None'
    }
    try { Set-PSReadLineOption @__opts } catch { }

    # Inline suggestions from your history (PSReadLine 2.1+; Windows PowerShell 5.1 ships 2.0)
    if ($__psrl.Version -ge [version]'2.1.0') {
        try { Set-PSReadLineOption -PredictionSource History } catch { }
    }

    # Type the start of a command, then Up/Down to search history for it
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Tab shows a menu of every match; F1 too (handy for parameters)
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key F1  -Function MenuComplete

    # Ctrl+D exits on an empty line (like bash); Ctrl+F accepts the next word of a suggestion
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
    Set-PSReadLineKeyHandler -Key Ctrl+f -Function ForwardWord

    # F2 toggles inline vs. list view for predictions (PSReadLine 2.2+)
    if ($__psrl.Version -ge [version]'2.2.0') {
        Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
    }

    # Never write lines that look like they contain secrets to the history file
    Set-PSReadLineOption -AddToHistoryHandler {
        param([string]$line)
        return ($line -notmatch '(?i)password|passwd|secret|token|apikey|api_key|-AsPlainText|ConvertTo-SecureString')
    }
}
Remove-Variable -Name __psrl, __opts -ErrorAction SilentlyContinue
