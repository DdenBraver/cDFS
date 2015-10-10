$DSCResourceName = 'BMD_cDFSRepGroupConnection'
$DSCModuleName   = 'cDFSRepGroupConnection'

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
        Description = 'Test Description'
        Members = @('FileServer1','FileServer2')
        Folders = @('Folder1','Folder2')
        DomainName = 'CONTOSO.COM'
    }
    $Global:RepGroupConnection = [PSObject]@{
        GroupName = 'Test Group'
        SourceComputerName = $Global:RepGroup.Members[0]
        DestinationComputerName = $Global:RepGroup.Members[1]
        Ensure = 'Present'
        Description = 'Connection Description'
        DisableConnection = $false
        DisableRDC = $false
        DomainName = 'CONTOSO.COM'
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
        ComputerName = $Global:RepGroup.ComputerName
        ContentPath = 'd:\public\software\'
        StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
        ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
        ReadOnly = $False
    }
    $Global:MockRepGroupConnection = [PSObject]@{
        GroupName = $Global:RepGroupConnection.GroupName
        SourceComputerName = $Global:RepGroupConnection.SourceComputerName
        DestinationComputerName = $Global:RepGroupConnection.DestinationComputerName
        Description = $Global:RepGroupConnection.Description
        Enabled = (-not $Global:RepGroupConnection.DisableConnection)
        RDCEnabled = (-not $Global:RepGroupConnection.DisableRDC)
        DomainName = $Global:RepGroupConnection.DomainName
    }

######################################################################################

    Describe 'Get-TargetResource' {

        Context 'No replication group connections exist' {
            
            Mock Get-DfsrConnection

            It 'should return absent replication group connection' {
                $Result = Get-TargetResource `
                    -GroupName $Global:RepGroupConnection.GroupName `
                    -SourceComputerName $Global:RepGroupConnection.SourceComputerName `
                    -DestinationComputerName $Global:RepGroupConnection.DestinationComputerName `
                    -Ensure Present
                $Result.Ensure | Should Be 'Absent'
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Requested replication group connection does exist' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }

            It 'should return correct replication group' {
                $Result = Get-TargetResource `
                    -GroupName $Global:RepGroupConnection.GroupName `
                    -SourceComputerName $Global:RepGroupConnection.SourceComputerName `
                    -DestinationComputerName $Global:RepGroupConnection.DestinationComputerName `
                    -Ensure Present
                $Result.Ensure | Should Be 'Present'
                $Result.GroupName | Should Be $Global:RepGroupConnection.GroupName
                $Result.SourceComputerName | Should Be $Global:RepGroupConnection.SourceComputerName
                $Result.DestinationComputerName | Should Be $Global:RepGroupConnection.DestinationComputerName
                $Result.Description | Should Be $Global:RepGroupConnection.Description
                $Result.DisableConnection | Should Be $Global:RepGroupConnection.DisableConnection
                $Result.DisableRDC | Should Be $Global:RepGroupConnection.DisableRDC
                $Result.DomainName | Should Be $Global:RepGroupConnection.DomainName
            }
            It 'should call the expected mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }
    }

######################################################################################

    Describe 'Set-TargetResource' {

        Context 'Replication Group connection does not exist but should' {
            
            Mock Get-DfsrConnection
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
            }
        }

        Context 'Replication Group connection exists but has different Description' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                    $Splat.Description = 'Changed'
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
            }
        }

        Context 'Replication Group connection exists but has different DisableConnection' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                    $Splat.DisableConnection = (-not $Splat.DisableConnection)
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
            }
        }

        Context 'Replication Group connection exists but has different DisableRDC' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                    $Splat.DisableRDC = (-not $Splat.DisableRDC)
                    $Splat.Description = 'Changed'
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
            }
        }


        Context 'Replication Group connection exists but should not' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                    $Splat.Ensure = 'Absent'
                    Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group connection exists and is correct' {
            
            Mock Get-DfsrConnection -MockWith { return @($Global:MockRepGroupConnection) }
            Mock Set-DfsrConnection
            Mock Add-DfsrConnection
            Mock Remove-DfsrConnection

            It 'should not throw error' {
                { 
                    $Splat = $Global:RepGroupConnection.Clone()
                   Set-TargetResource @Splat
                } | Should Not Throw
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
            }
        }
    }

######################################################################################

    Describe 'Test-TargetResource' {
        Context 'Replication Group Connection does not exist but should' {
            
            Mock Get-DfsrConnection

            It 'should return false' {
                $Splat = $Global:RepGroupConnection.Clone()
                Test-TargetResource @Splat | Should Be $False 
                
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group Connection exists but has different Description' {
            
            Mock Get-DfsrConnection -MockWith { @($Global:MockRepGroupConnection) }

            It 'should return false' {
                $Splat = $Global:RepGroupConnection.Clone()
                $Splat.Description = 'Changed'
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group Connection exists but has different DisableConnection' {
            
            Mock Get-DfsrConnection -MockWith { @($Global:MockRepGroupConnection) }

            It 'should return false' {
                $Splat = $Global:RepGroupConnection.Clone()
                $Splat.DisableConnection = (-not $Splat.DisableConnection)
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group Connection exists but has different DisableRDC' {
            
            Mock Get-DfsrConnection -MockWith { @($Global:MockRepGroupConnection) }

            It 'should return false' {
                $Splat = $Global:RepGroupConnection.Clone()
                $Splat.DisableRDC = (-not $Splat.DisableRDC)
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group Connection exists but should not' {
            
            Mock Get-DfsrConnection -MockWith { @($Global:MockRepGroupConnection) }

            It 'should return false' {
                $Splat = $Global:RepGroupConnection.Clone()
                $Splat.Ensure = 'Absent'
                Test-TargetResource @Splat | Should Be $False
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
            }
        }

        Context 'Replication Group Connection exists and is correct' {
            
            Mock Get-DfsrConnection -MockWith { @($Global:MockRepGroupConnection) }

            It 'should return true' {
                $Splat = $Global:RepGroupConnection.Clone()
                Test-TargetResource @Splat | Should Be $True
            }
            It 'should call expected Mocks' {
                Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
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