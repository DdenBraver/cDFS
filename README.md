[![Build status](https://ci.appveyor.com/api/projects/status/tf23k8l44u1k3wnt/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/cdfs/branch/master)

# cDFS

The **cDFS** module contains DSC resources for configuring Distributed File System Replication and Namespaces. Currently in this version only Replication folders are supported. Namespaces will be supported in a future release.

## Requirements
* **Windows Management Framework 5.0**: Required because the PSDSCRunAsCredential DSC Resource parameter is needed.

## Installation
```powershell
Install-Module -Name cDFS -MinimumVersion 1.0.0.0
```

## Important Information
### DFSR Module
This DSC Resource requires that the DFSR PowerShell module is installed onto any computer this resource will be used on. This module is installed as part of RSAT tools or RSAT-DFS-Mgmt-Con Windows Feature in Windows Server 2012 R2.
However, this will automatically convert a Server Core installation into one containing the managment tools, which may not be ideal because it is no longer strictly a Server Core installation.
Because this DSC Resource actually only configures information within the AD, it is only required that this resource is run on a computer that is registered in AD. It doesn't need to be run on one of the File Servers participating
in the Distributed File System or Namespace.

### Domain Credentials
Because this resource is configuring information within Active Directory, the **PSDSCRunAsCredential** property must be used with a credential of a domain user that can work with DFS information. This means that this resource can only work on computers with Windows Management Framework 5.0 or above.


## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Resources
### cDFSRepGroup
This resource is used to create, edit or remove DFS Replication Groups. If used to create a Replcation Group it should be combined with the cDFSRepGroupMembership resources.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group is either Absent or Present. Required.
* **Description**: A description for the Replication Group. Optional.
* **Members**: A list of computers that are members of this Replication Group. Optional.
* **Folders**: A list of folders that are replicated in this Replication Group. Optional.
* **Topology**: This allows a replication topology to assign to the Replication Group. It defaults to Manual, which will not automatically create a topology. If set to Fullmesh, a full mesh topology between all members will be created. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### cDFSRepGroupConnection
This resource is used to create, edit and remove DFS Replication Group connections. This resource should ONLY be used if the Topology parameter in the Resource Group is set to Manual.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group connection is either Absent or Present. Required.
* **SourceComputerName**: The name of the Replication Group source computer for the connection. Required.
* **DestinationComputerName**: The name of the Replication Group destination computer for the connection. Required.
* **Description**: A description for the Replication Group connection. Optional.
* **DisableConnection**: Set to $true to disable this connection. Optional.
* **RDCDisable**: Set to $true to disable remote differention compression on this connection. Optional.
* **DomainName**: The AD domain the Replication Group connection should created in. Optional.

### cDFSRepGroupFolder
This resource is used to configure DFS Replication Group folders. This is an optional resource, and only needs to be used if the folder Description, FilenameToExclude or DirectoryNameToExclude fields need to be set. In most cases just setting the Folders property in the cDFSRepGroup resource will be acceptable.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The name of the Replication Group folder. Required.
* **Description**: A description for the Replication Group. Optional.
* **FilenameToExclude**: An array of file names to exclude from replication. Optional.
* **DirectoryNameToExclude**: An array of directory names to exclude from replication. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### cDFSRepGroupMembership
This resource is used to configure Replication Group Folder Membership. It is usually used to set the **ContentPath** for each Replication Group folder on each Member computer. It can also be used to set additional properties of the Membership.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The folder name of the Replication Group folder. Required.
* **ComputerName**: The computer name of the Replication Group member. Required.
* **ContentPath**: The local content path for this folder member. Required.
* **StagingPath**: Ths staging path for this folder member. Optional.
* **ReadOnly**: Used to set this folder member to read only. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

#### Examples
Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. A manual topology is assigned to the replication connections.
```powershell
configuration Sample_cDFSRepGroup
{
    Import-DscResource -Module cDFS

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))

        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
        }

        # Configure the Replication Group
        cDFSRepGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        cDFSRepGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1'
            DestinationComputerName = 'FileServer2'
            PSDSCRunAsCredential = $Credential
        } # End of cDFSRepGroupConnection Resource

        cDFSRepGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2'
            DestinationComputerName = 'FileServer1'
            PSDSCRunAsCredential = $Credential
        } # End of cDFSRepGroupConnection Resource

        cDFSRepGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroup]RGPublic'
        } # End of RGPublic Resource

        cDFSRepGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        cDFSRepGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
```


Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. An automatic fullmesh topology is assigned to the replication group connections.
```powershell
configuration Sample_cDFSRepGroup_FullMesh
{
    Import-DscResource -Module cDFS

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))

        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
        }

        # Configure the Replication Group
        cDFSRepGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software'
            Topology = 'Fullmesh'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        cDFSRepGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroup]RGPublic'
        } # End of RGPublic Resource

        cDFSRepGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        cDFSRepGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
```

## Versions

### 1.1.0.0

* cDFSRepGroupConnection- Resource added.

### 1.0.0.0

* Initial release.

## Links
* **[GitHub Repo](https://github.com/PlagueHO/cDFS)**: Raise any issues, requests or PRs here.
* **[My Blog](https://dscottraynsford.wordpress.com)**: See my PowerShell and Programming Blog.
