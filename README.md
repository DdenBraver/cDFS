[![Build status](https://ci.appveyor.com/api/projects/status/tf23k8l44u1k3wnt/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/cdfs/branch/master)

# cDFS

The **cDFS** module contains DSC resources for configuring Distributed File System Replication and Namespaces.

## Installation
### Installation if WMF5.0 is Installed
```powershell	
Install-Module -Name cDFS -MinimumVersion 1.0.0.0
```

### Installation if WMF5.0 is Not Installed

    Unzip the content under $env:ProgramFiles\WindowsPowerShell\Modules folder 

To confirm installation:

    Run Get-DSCResource to see that cDFS is among the DSC Resources listed 

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


### cDFSRepGroup
This resource is used to create, edit or remove DFS Replication Groups. If used to create a Replcation Group it should be combined with the cDFSRepGroupMembership resources.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replicatio Group is either Absent or Present. Required.
* **Description**: A description for the Replication Group. Optional.
* **Members**: A list of computers that are members of this Replication Group. Optional.
* **Folders**: A list of folders that are replicated in this Replication Group. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

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
* **ConflictAndDeletedPath**: Ths conflict and deleted file path for this folder member. Optional.
* **ReadOnly**: Used to set this folder member to read only. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

#### Examples

## Versions

### 1.0.0.0

* Initial release.
