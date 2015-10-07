$DSCResourceName = 'BMD_cDFSRepGroup'
$DSCModuleName   = 'cDFSRepGroup'

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
            ComputerName = 'FileServer1'
        },
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            ComputerName = 'FileServer2'
        }
    )
    $Global:MockRepGroupFolder = @(
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            FolderName = 'Folder1'
            Description = 'Description 1'
            FileNameToExclude = @('~*','*.bak','*.tmp')
            DirectoryNameToExclude = @()
        },
        [PSObject]@{
            GroupName = $Global:RepGroup.GroupName
            DomainName = $Global:RepGroup.DomainName
            FolderName = 'Folder2'
            Description = 'Description 2'
            FileNameToExclude = @('~*','*.bak','*.tmp')
            DirectoryNameToExclude = @()
        }
    )

######################################################################################

    Describe 'Get-TargetResource' {

        Context 'No replication groups exist' {
            
            Mock Get-DfsReplicationGroup

            It 'should return absent replication group' {
                $Result = Get-TargetResource `
                    -GroupName $Global:RepGroup.GroupName `
                    -Ensure Present
                $Result.Ensure | Should Be 'Absent'
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
            }
        }

        Context 'Requested replication group does exist' {
            
            Mock Get-DfsReplicationGroup -MockWith { return @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return correct replication group' {
                $Result = Get-TargetResource `
                    -GroupName $Global:RepGroup.GroupName `
                    -Ensure Present
                $Result.Ensure | Should Be 'Present'
                $Result.GroupName | Should Be $Global:RepGroup.GroupName
                $Result.Description | Should Be $Global:RepGroup.Description
                $Result.DomainName | Should Be $Global:RepGroup.DomainName
                $Result.Members | Should Be $Global:RepGroup.Members
                $Result.Folders | Should Be $Global:RepGroup.Folders
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }
    }

######################################################################################

    Describe 'Set-TargetResource' {

        Context 'Replication Group does not exist but should' {
            
            Mock Get-DfsReplicationGroup
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 2
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 2
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but has different description' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Description = 'Changed'
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but is missing a member' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Members = @('FileServer2','FileServer1','FileServerNew')
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but has an extra member' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Members = @('FileServer2')
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but is missing a folder' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Folders = @('Folder2','Folder1','FolderNew')
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but has an extra folder' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Folders = @('Folder2')
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 1
            }
        }

        Context 'Replication Group exists but should not' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                    $Splat.Ensure = 'Absent'
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists and is correct' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock New-DfsReplicationGroup
            Mock Set-DfsReplicationGroup
            Mock Remove-DfsReplicationGroup
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Add-DfsrMember
            Mock Remove-DfsrMember
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }
            Mock New-DfsReplicatedFolder
            Mock Remove-DfsReplicatedFolder

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroup.Clone()
                   Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
            }
        }
    }

######################################################################################

    Describe 'Test-TargetResource' {
        Context 'Replication Group does not exist but should' {
            
            Mock Get-DfsReplicationGroup
            Mock Get-DfsrMember
            Mock Get-DfsReplicatedFolder

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                Test-TargetResource @Splat | Should Be $False
                
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists but has different description' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Description = 'Changed'
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
            }
        }

        Context 'Replication Group exists but is missing a member' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Members = @('FileServer2','FileServer1','FileServerNew')
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }

        Context 'Replication Group exists but has an extra member' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Members = @('FileServer2')
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }

        Context 'Replication Group exists but is missing a folder' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Folders = @('Folder2','Folder1','FolderNew')
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }

        Context 'Replication Group exists but has an extra folder' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Folders = @('Folder2')
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }
        Context 'Replication Group exists but should not' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return false' {
                $Splat = $Global:RepGroup.Clone()
                $Splat.Ensure = 'Absent'
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
            }
        }

        Context 'Replication Group exists and is correct' {
            
            Mock Get-DfsReplicationGroup -MockWith { @($Global:MockRepGroup) }
            Mock Get-DfsrMember -MockWith { return $Global:MockRepGroupMember }
            Mock Get-DfsReplicatedFolder -MockWith { return $Global:MockRepGroupFolder }

            It 'should return true' {
                $Splat = $Global:RepGroup.Clone()
                Test-TargetResource @Splat | Should Be $True
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
            }
        }
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