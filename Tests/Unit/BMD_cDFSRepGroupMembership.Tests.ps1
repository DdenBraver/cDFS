$DSCResourceName = 'BMD_cDFSRepGroupMembership'
$DSCModuleName   = 'cDFS'

$Splat = @{
    Path = $PSScriptRoot
    ChildPath = "..\..\DSCResources\$DSCResourceName\$DSCResourceName.psm1"
    Resolve = $true
    ErrorAction = 'Stop'
}

$DSCResourceModuleFile = Get-Item -Path (Join-Path @Splat)

$moduleRoot = "${env:ProgramFiles}\WindowsPowerShell\Modules\$DSCModuleName"

if(-not (Test-Path -Path $moduleRoot))
{
    $null = New-Item -Path $moduleRoot -ItemType Directory
}
else
{
    # Copy the existing folder out to the temp directory to hold until the end of the run
    # Delete the folder to remove the old files.
    $tempLocation = Join-Path -Path $env:Temp -ChildPath $DSCModuleName
    Copy-Item -Path $moduleRoot -Destination $tempLocation -Recurse -Force
    Remove-Item -Path $moduleRoot -Recurse -Force
    $null = New-Item -Path $moduleRoot -ItemType Directory
}

Copy-Item -Path $PSScriptRoot\..\..\* -Destination $moduleRoot -Recurse -Force -Exclude '.git'

if (Get-Module -Name $DSCResourceName)
{
    Remove-Module -Name $DSCResourceName
}

Import-Module -Name $DSCResourceModuleFile.FullName -Force

$breakvar = $True

InModuleScope $DSCResourceName {

######################################################################################

    # Create the Mock Objects that will be used for running tests
    $Global:RepGroup = [PSObject]@{
        GroupName = 'Test Group'
        Ensure = 'Present'
        DomainName = 'CONTOSO.COM'
        Description = 'Test Description'
        Members = @('FileServer1','FileServer2')
        Folders = @('Folder1','Folder2')
    }
    $Global:MockRepGroup = [PSObject]@{
        GroupName = $Global:RepGroup.GroupName
        DomainName = $Global:RepGroup.DomainName
        Description = $Global:RepGroup.Description
    }
    $Global:MockRepGroupMember = @(
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            ComputerName = $Global:RepGroup.Members[0]
        },
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            ComputerName = $Global:RepGroup.Members[1]
        }
    )
    $Global:MockRepGroupFolder = @(
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            FolderName = $Global:RepGroup.Folders[0]
            Description = 'Description 1'
            FileNameToExclude = @('~*','*.bak','*.tmp')
            DirectoryNameToExclude = @()
        },
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            FolderName = $Global:RepGroup.Folders[1]
            Description = 'Description 2'
            FileNameToExclude = @('~*','*.bak','*.tmp')
            DirectoryNameToExclude = @()
        }
    )
    $Global:MockRepGroupMembership = [PSObject]@{
        GroupName = $Global:RepGroup.GroupName
        DomainName = $Global:RepGroup.DomainName
        FolderName = $Global:RepGroup.Folders[0]
        ComputerName = $Global:RepGroup.Members[0]
        ContentPath = 'd:\public\software\'
        StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
        ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
        ReadOnly = $False
    }

######################################################################################

    Describe 'Get-TargetResource' {

        Context 'Replication group folder does not exist' {
            
            Mock Get-DfsrMembership

            It 'should throw RegGroupFolderMissingError error' {
                $errorId = 'RegGroupMembershipMissingError'
                $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                $errorMessage = $($LocalizedData.RepGroupMembershipMissingError) `
                    -f $Global:MockRepGroupMembership.GroupName,$Global:MockRepGroupMembership.FolderName,$Global:MockRepGroupMembership.ComputerName
                $exception = New-Object -TypeName System.InvalidOperationException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                {
                    $Result = Get-TargetResource `
                        -GroupName $Global:MockRepGroupMembership.GroupName `
                        -FolderName $Global:MockRepGroupMembership.FolderName `
                        -ComputerName $Global:MockRepGroupMembership.ComputerName
                } | Should Throw $errorRecord               
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
            }
        }

        Context 'Requested replication group does exist' {
            
            Mock Get-DfsrMembership -MockWith { return @($Global:MockRepGroupMembership) }

            It 'should return correct replication group' {
                $Result = Get-TargetResource `
                        -GroupName $Global:MockRepGroupMembership.GroupName `
                        -FolderName $Global:MockRepGroupMembership.FolderName `
                        -ComputerName $Global:MockRepGroupMembership.ComputerName
                $Result.GroupName | Should Be $Global:MockRepGroupMembership.GroupName
                $Result.FolderName | Should Be $Global:MockRepGroupMembership.FolderName               
                $Result.ComputerName | Should Be $Global:MockRepGroupMembership.ComputerName               
                $Result.DomainName | Should Be $Global:MockRepGroupMembership.DomainName
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
            }
        }
    }

######################################################################################

    Describe 'Set-TargetResource' {

    }

######################################################################################

    Describe 'Test-TargetResource' {

    }

######################################################################################

}

# Clean up after the test completes.
Remove-Item -Path $moduleRoot -Recurse -Force

# Restore previous versions, if it exists.
if ($tempLocation)
{
    $null = New-Item -Path $moduleRoot -ItemType Directory
    $script:Destination = "${env:ProgramFiles}\WindowsPowerShell\Modules"
    Copy-Item -Path $tempLocation -Destination $script:Destination -Recurse -Force
    Remove-Item -Path $tempLocation -Recurse -Force
}