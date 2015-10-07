#######################################################################################
#  cDFSRepGroup : DSC Resource This resource is used to create, edit or remove DFS
#  Replication Groups. If used to create a Replcation Group it should be combined with
#  the cDFSRepGroupFolder and cDFSRepGroupMembership resources.
#######################################################################################
 
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
GettingRepGroupMessage=Getting DFS Replication Group "{0}".
RepGroupExistsMessage=DFS Replication Group "{0}" exists.
RepGroupDoesNotExistMessage=DFS Replication Group "{0}" does not exist.
SettingRegGroupMessage=Setting DFS Replication Group "{0}".
EnsureRepGroupExistsMessage=Ensuring DFS Replication Group "{0}" exists.
EnsureRepGroupDoesNotExistMessage=Ensuring DFS Replication Group "{0}" does not exist.
RepGroupCreatedMessage=DFS Replication Group "{0}" has been created.
RepGroupDescriptionUpdatedMessage=DFS Replication Group "{0}" description has been updated.
RepGroupMemberAddedMessage=DFS Replication Group "{0}" added member "{2}".
RepGroupMemberRemovedMessage=DFS Replication Group "{0}" removed member "{2}".
RepGroupFolderAddedMessage=DFS Replication Group "{0}" added folder "{2}".
RepGroupFolderRemovedMessage=DFS Replication Group "{0}" removed folder "{2}".
RepGroupExistsRemovedMessage=DFS Replication Group "{0}" existed, but has been removed.
TestingRegGroupMessage=Testing DFS Replication Group "{0}".
RepGroupDescriptionNeedsUpdateMessage=DFS Replication Group "{0}" description is different. Change required.
RepGroupMembersNeedUpdateMessage=DFS Replication Group "{0}" members are different. Change required.
RepGrouFoldersNeedUpdateMessage=DFS Replication Group "{0}" folders are different. Change required.
RepGroupDoesNotExistButShouldMessage=DFS Replication Group "{0}" does not exist but should. Change required.
RepGroupExistsButShouldNotMessage=DFS Replication Group "{0}" exists but should not. Change required.
RepGroupDoesNotExistAndShouldNotMessage=DFS Replication Group "{0}" does not exist and should not. Change not required.
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
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $DomainName
    )
    
    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingRepGroupMessage) -f $GroupName,$DomainName
        ) -join '' )

    $returnValue = @{
        GroupName = $GroupName
    }

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DfsReplicationGroup @Splat -ErrorAction Stop
    if ($RepGroup) {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupExistsMessage) -f $GroupName,$DomainName
            ) -join '' )
        $returnValue += @{
            Ensure = 'Present'
            Description = $RepGroup.Description
            DomainName = $RepGroup.DomainName
            Members = (Get-DfsrMember @Splat -ErrorAction Stop).ComputerName
            Folders = (Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName
        }
    } Else {       
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupDoesNotExistMessage) -f $GroupName,$DomainName
            ) -join '' )
        $returnValue += @{ Ensure = 'Absent' }
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
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [String[]]
        $Members,

        [String[]]
        $Folders,

        [String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupMessage) -f $GroupName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DfsReplicationGroup @Splat -ErrorAction Stop

    if ($Ensure -eq 'Present') {
        # The rep group should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupExistsMessage) -f $GroupName,$DomainName
            ) -join '' )

        if ($RepGroup) {
            # The RG exists already - Check the existing RG and members
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsMessage) -f $GroupName,$DomainName
                ) -join '' )
            # Check the description
            if (($Description) -and ($RepGroup.Description -ne $Description)) {
                Set-DfsReplicationGroup @Splat -Description $Description -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupDescriptionUpdatedMessage) -f $GroupName,$DomainName
                    ) -join '' )
            }

        } else {
            # Ths Rep Groups doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupDoesNotExistMessage) -f $GroupName,$DomainName
                ) -join '' )
            if ($Description) {
                $Splat += @{ Description = $Description }
            }
            New-DfsReplicationGroup @Splat -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupCreatedMessage) -f $GroupName,$DomainName
                ) -join '' )

        }

        # Clean up the splat so we can use it in the next cmdlets
        $Splat.Remove('Description')
        
        # Get the existing members of this DFS Rep Group
        $ExistingMembers = (Get-DfsrMember @Splat -ErrorAction Stop).ComputerName

        # Add any missing members
        foreach ($Member in $Members) {
            if ($Member -notin $ExistingMembers) {
                # Member is missing - add it
                Add-DfsrMember @Splat -ComputerName $Member -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMemberAddedMessage) -f $GroupName,$DomainName,$Member
                    ) -join '' )
            }
        }

        # Remove any members that shouldn't exist
        foreach ($ExistingMember in $ExistingMembers) {
            if ($ExistingMember -notin $Members) {
                # Member exists but shouldn't - remove it
                Remove-DfsrMember @Splat -ComputerName $ExistingMember -Force -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMemberRemovedMessage) -f $GroupName,$DomainName,$ExistingMember
                    ) -join '' )
            }
        }

        # Get the existing folders of this DFS Rep Group
        $ExistingFolders = (Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName

        # Add any missing folders
        foreach ($Folder in $Folders) {
            if ($Folder -notin $ExistingFolders) {
                # Folder is missing - add it
                New-DfsReplicatedFolder @Splat -FolderName $Folder -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFolderAddedMessage) -f $GroupName,$DomainName,$Folder
                    ) -join '' )
            }
        }

        # Remove any folders that shouldn't exist
        foreach ($ExistingFolder in $ExistingFolders) {
            if ($ExistingFolder -notin $Folders) {
                # Folder exists but shouldn't - remove it
                Remove-DfsReplicatedFolder @Splat -Folder $ExistingFolder -Force -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFolderRemovedMessage) -f $GroupName,$DomainName,$ExistingFolder
                    ) -join '' )
            }
        }
    } else {
        # The Rep Group should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupDoesNotExistMessage) -f $GroupName,$DomainName
            ) -join '' )
        if ($RepGroup) {
            # Remove the replication group
            Remove-DfsReplicationGroup @Splat -RemoveReplicatedFolders -Force -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsRemovedMessage) -f $GroupName,$DomainName
                ) -join '' )
        }
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
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [String[]]
        $Members,

        [String[]]
        $Folders,

        [String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupMessage) -f $GroupName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    if ($DomainName) {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DFSReplicationGroup @Splat -ErrorAction Stop

    if ($Ensure -eq 'Present') {
        # The RG should exist
        if ($RepGroup) {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsMessage) -f $GroupName,$DomainName
                ) -join '' )

            # Check the description
            if (($Description) -and ($RepGroup.Description -ne $Description)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupDescriptionNeedsUpdateMessage) -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            # Compare the Members
            $ExistingMembers = (Get-DfsrMember @Splat -ErrorAction Stop).ComputerName
            if ((Compare-Object `
                -ReferenceObject $Members `
                -DifferenceObject $ExistingMembers).Count -ne 0) {
                # There is a member different of some kind.
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMembersNeedUpdateMessage) -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false                
            }

            # Compare the Folders
            $ExistingFolders = (Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName
            if ((Compare-Object `
                -ReferenceObject $Folders `
                -DifferenceObject $ExistingFolders).Count -ne 0) {
                # There is a folder different of some kind.
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFoldersNeedUpdateMessage) -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false                
            }
        } else {
            # Ths RG doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupDoesNotExistButShouldMessage) -f  $GroupName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    } else {
        # The RG should not exist
        if ($RepGroup) {
            # The RG exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupExistsButShouldNotMessage) -f $GroupName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        } else {
            # The RG does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupDoesNotExistAndShouldNotMessage) -f $GroupName,$DomainName
                ) -join '' )
        }
    } # if
    return $desiredConfigurationMatch
} # Test-TargetResource
######################################################################################

Export-ModuleMember -Function *-TargetResource