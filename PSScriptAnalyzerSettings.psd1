@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',                    # interactive helpers print on purpose
        'PSAvoidGlobalVars',                        # the loader works in global scope by design
        'PSUseSingularNouns',                       # Get-LockedUsers, Unblock-Downloads read better
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingInvokeExpression',             # deferred tool init (gh, zoxide)
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSReviewUnusedParameter',
        'PSAvoidAssignmentToAutomaticVariable'
    )
}
