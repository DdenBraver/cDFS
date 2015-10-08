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
GettingRepGroupFolderMessage=Getting DFS Replication Group Folder "{0}" folder "{1}".
RepGroupFolderExistsMessage=DFS Replication Group "{0}" folder "{1}" exists.
RepGroupFolderDoesNotExistMessage=DFS Replication Group "{0}" folder "{1}" does not exist.
SettingRegGroupFolderMessage=Setting DFS Replication Group Folder "{0}" folder "{1}".
RepGroupExistsMessage=DFS Replication Group "{0}" folder "{1}" exists.
RepGroupFolderDescriptionUpdateMessage=DFS Replication Group "{0}" folder "{1}" has incorrect Description. Updating.
RepGroupFolderFileNameToExcludeUpdateMessage=DFS Replication Group "{0}" folder "{1}" has incorrect FileNameToExclude. Updating.
RepGroupFolderDirectoryNameToExcludeUpdateMessage=DFS Replication Group "{0}" folder "{1}" has incorrect DirectoryNameToExclude. Updating.
RepGroupFolderUpdatedMessage=DFS Replication Group "{0}" folder "{1}" has has been updated.
RepGroupFolderMissingError=DFS Replication Group "{0}" folder "{1}" is missing.
TestingRegGroupFolderMessage=Testing DFS Replication Group Folder "{0}" folder "{1}".
RepGroupFolderDescriptionMismatchMessage=DFS Replication Group "{0}" folder "{1}" has incorrect Description. Change required.
RepGroupFolderFileNameToExcludeMismatchMessage=DFS Replication Group "{0}" folder "{1}" has incorrect FileNameToExclude. Change required.
RepGroupFolderDirectoryNameToExcludeMismatchMessage=DFS Replication Group "{0}" folder "{1}" has incorrect DirectoryNameToExclude. Change required.
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

        [String]
        $DomainName
    )
    
    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingRepGroupFolderMessage) -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    $returnValue = @{
        GroupName = $GroupName
        FolderName = $FolderName
    }

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName; FolderName = $FolderName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroupFolder = Get-DfsReplicatedFolder @Splat -ErrorAction Stop
    if ($RepGroupFolder) {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupFolderExistsMessage) -f $GroupName,$FolderName,$DomainName
            ) -join '' )
        $returnValue += @{
            Description = $RepGroupFolder.Description
            FilenameToExclude = $RepGroupFolder.FilenameToExclude
            DirectoryNameToExclude = $RepGroupFolder.DirectoryNameToExclude
            DomainName = $RepGroupFolder.DomainName
        }
    } Else {       
        # The Rep Group folder doesn't exist
        $errorId = 'RegGroupFolderMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.RepGroupFolderMissingError) -f $GroupName,$FolderName,$DomainName
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

        [String]
        $Description,

        [String[]]
        $FileNameToExclude,

        [String[]]
        $DirectoryNameToExclude,

        [String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupFolderMessage) -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group Folder
    $Splat = @{ GroupName = $GroupName; FolderName = $FolderName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroupFolder = Get-DfsReplicatedFolder @Splat -ErrorAction Stop

    if ($RepGroupFolder) {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupExistsMessage) -f $GroupName,$FolderName,$DomainName
            ) -join '' )

        # Check the description
        if (($Description -ne $null) -and ($RepGroupFolder.Description -ne $Description)) {
            $Splat += @{ Description = $Description }
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderDescriptionUpdateMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
        }
        
        # Check the FileNameToExclude
        if (($FileNameToExclude -ne $null) `
            -and ((Compare-Object `
                -ReferenceObject  $RepGroupFolder.FileNameToExclude `
                -DifferenceObject $FileNameToExclude) -ne 0)) {
            $Splat += @{ FileNameToExclude = $FileNameToExclude }
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderFileNameToExcludeUpdateMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
        }

        # Check the DirectoryNameToExclude
        if (($DirectoryNameToExclude -ne $null) `
            -and ((Compare-Object `
                -ReferenceObject  $RepGroupFolder.DirectoryNameToExclude `
                -DifferenceObject $DirectoryNameToExclude) -ne 0)) {
            $Splat += @{ DirectoryNameToExclude = $DirectoryNameToExclude }
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderDirectoryNameToExcludeUpdateMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
        }

        # Now apply the changes that have been loaded into the splat
        Set-DfsReplicatedFolder @Splat -ErrorAction Stop

        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupFolderUpdatedMessage) -f $GroupName,$FolderName,$DomainName
            ) -join '' )

    } else {
        # The Rep Group folder doesn't exist
        $errorId = 'RegGroupFolderMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.RepGroupFolderMissingError) -f $GroupName,$FolderName,$DomainName
        $exception = New-Object -TypeName System.InvalidOperationException `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord)
    } # if
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

        [String]
        $Description,

        [String[]]
        $FileNameToExclude,

        [String[]]
        $DirectoryNameToExclude,

        [String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupFolderMessage) -f $GroupName,$FolderName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group Folder
    $Splat = @{ GroupName = $GroupName; FolderName = $FolderName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroupFolder = Get-DfsReplicatedFolder @Splat -ErrorAction Stop

    if ($RepGroupFolder) {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupExistsMessage) -f $GroupName,$DomainName
            ) -join '' )

        # Check the description
        if (($Description -ne $null) -and ($RepGroupFolder.Description -ne $Description)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderDescriptionMismatchMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        
        # Check the FileNameToExclude
        if (($FileNameToExclude -ne $null) `
            -and ((Compare-Object `
                -ReferenceObject  $RepGroupFolder.FileNameToExclude `
                -DifferenceObject $FileNameToExclude).Count -ne 0)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderFileNameToExcludeMismatchMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }

        # Check the DirectoryNameToExclude
        if (($DirectoryNameToExclude -ne $null) `
            -and ((Compare-Object `
                -ReferenceObject  $RepGroupFolder.DirectoryNameToExclude `
                -DifferenceObject $DirectoryNameToExclude).Count -ne 0)) {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupFolderDirectoryNameToExcludeMismatchMessage) -f $GroupName,$FolderName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    } else {
        # The Rep Group folder doesn't exist
        $errorId = 'RegGroupFolderMissingError'
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
        $errorMessage = $($LocalizedData.RepGroupFolderMissingError) -f $GroupName,$FolderName,$DomainName
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