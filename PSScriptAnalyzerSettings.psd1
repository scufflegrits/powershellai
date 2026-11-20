@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
        PSUseApprovedVerbs = @{
            Enable = $true
        }
    }
}
