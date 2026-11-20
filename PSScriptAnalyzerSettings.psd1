# Repository analyzer settings. Default rules run in addition to the rules configured below.
# Validated with PSScriptAnalyzer 1.24.0, the version pinned in CI.
@{
    Severity = @('Error', 'Warning')
    Rules    = @{
        # The project targets PowerShell 7.0+; flag syntax unavailable there.
        PSUseCompatibleSyntax      = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }

        # Formatting: one true brace style with 4-space indentation, matching the guide's examples.
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace  = @{
            Enable                          = $true
            CheckInnerBrace                 = $true
            CheckOpenBrace                  = $true
            CheckOpenParen                  = $true
            # Off because it flags the aligned '=' that PSAlignAssignmentStatement requires.
            CheckOperator                   = $false
            CheckPipe                       = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                  = $true
            CheckParameter                  = $false
        }
        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }
    }
}
