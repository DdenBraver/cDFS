#######################################################################################
#  cDFSRepGroupMembership : This resource is used to configure Replication Group Folder
#  Membership. It is usually used to set the **ContentPath** for each Replication Group
#  folder on each Member computer. It can also be used to set additional properties of
#  the Membership.
#######################################################################################
 
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
GettingRepGroupMembershipMessage=Getting DFS Replication Group "{0}" folder "{1}" on "{2}".
RepGroupMembershipExistsMessage=DFS Replication Group "{0}" folder "{1}" on "{2}" exists.
RepGroupMembershipMissingError=DFS Replication Group "{0}" folder "{1}" on "{2}" is missing.
SettingRegGroupMembershipMessage=Setting DFS Replication Group "{0}" folder "{1}" on "{2}".
RepGroupMembershipUpdatedMessage=DFS Replication Group "{0}" folder "{1}" on "{2}" has has been updated.
TestingRegGroupMembershipMessage=Testing DFS Replication Group "{0}" folder "{1}" on "{2}".
RepGroupMembershipContentPathMismatchMessage=DFS Replication Group "{0}" folder "{1}" on "{2}" has incorrect ContentPath. Change required.
RepGroupMembershipStagingPathMismatchMessage=DFS Replication Group "{0}" folder "{1}" on "{2}" has incorrect StagingPath. Change required.
RepGroupMembershipReadOnlyMismatchMessage=DFS Replication Group "{0}" folder "{1}" on "{2}" has incorrect ReadOnly. Change required.
'@
}


######################################################################################
# The Get-TargetResource cmdlet.
######################################################################################
function Get-TargetResource
{
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [String]
        $FolderName,

        [parameter(Mandatory = $true)]
        [String]
        $ComputerName,

        [String]
        $DomainName
    )
    
    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingRepGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName; ComputerName = $ComputerName }
    $returnValue = $Splat
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $returnValue += @{ FolderName = $FolderName }
    $RepGroupMembership = Get-DfsrMembership @Splat -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }
    if ($RepGroupMembership) {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName,$DomainName
            ) -join '' )
        $returnValue += @{
            ContentPath = $RepGroupMembership.ContentPath
            StagingPath = $RepGroupMembership.StagingPath
            ConflictAndDeletedPath = $RepGroupMembership.ConflictAndDeletedPath
            ReadOnly = $RepGroupMembership.ReadOnly
            DomainName = $RepGroupMembership.DomainName
        }
    } Else {       
        # The Rep Group membership doesn't exist
        $errorId = 'RegGroupMembershipMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.RepGroupMembershipMissingError) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $returnValue
} # Get-TargetResource

######################################################################################
# The Set-TargetResource cmdlet.
######################################################################################
function Set-TargetResource
{
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [String]
        $FolderName,

        [parameter(Mandatory = $true)]
        [String]
        $ComputerName,

        [String]
        $ContentPath,

        [String]
        $StagingPath,

        [Boolean]
        $ReadOnly,

        [String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    $Splat = @{ GroupName = $GroupName; FolderName = $FolderName; ComputerName = $ComputerName }
    $returnValue = $Splat
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    if ($ContentPath -ne $null) {
        $Splat += @{ ContentPath = $ContentPath }
    }
    if ($StagingPath) {
        $Splat += @{ StagingPath = $StagingPath }
    }
    if ($ReadOnly -ne $null) {
        $Splat += @{ ReadOnly = $ReadOnly }
    }

    # Now apply the changes that have been loaded into the splat
    Set-DfsrMembership @Splat -ErrorAction Stop

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.RepGroupMembershipUpdatedMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )
} # Set-TargetResource

######################################################################################
# The Test-TargetResource cmdlet.
######################################################################################
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [String]
        $FolderName,

        [parameter(Mandatory = $true)]
        [String]
        $ComputerName,

        [String]
        $ContentPath,

        [String]
        $StagingPath,

        [Boolean]
        $ReadOnly,

        [String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName; ComputerName = $ComputerName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroupMembership = Get-DfsrMembership @Splat -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }
    if ($RepGroupMembership) {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName,$DomainName
            ) -join '' )

        # Check the ContentPath
        if (($ContentPath -ne $null) -and ($RepGroupMembership.ContentPath -ne $ContentPath)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupMembershipContentPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        
        # Check the StagingPath
        if (($StagingPath -ne $null) -and ($RepGroupMembership.StagingPath -ne $StagingPath)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupMembershipStagingPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the ReadOnly
        if (($ReadOnly -ne $null) -and ($RepGroupMembership.ReadOnly -ne $ReadOnly)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupMembershipReadOnlyMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

    } else {
        # The Rep Group membership doesn't exist
        $errorId = 'RegGroupMembershipMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.RepGroupMembershipMissingError) `
            -f $GroupName,$FolderName,$ComputerName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $desiredConfigurationMatch
} # Test-TargetResource
######################################################################################

Export-ModuleMember -Function *-TargetResource