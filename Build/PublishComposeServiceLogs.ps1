﻿# This script starts the Docker Compose services residing in a given compose file and will also
# create one Azure DevOps variable per port per service.
Param(
    # Docker Compose project name.
    # See more here: https://docs.docker.com/compose/reference/overview/#use--p-to-specify-a-project-name.
    [String]
    $ComposeProjectName = 'aspnet-core-logging-it',

    # The path to the folder where Docker Compose will write its logs.
    [String]
    $LogsOutputFolder
)

Write-Output "Start publishing logs for compose services from project: $ComposeProjectName"

$LsCommandOutput = docker container ls -a `
                                    --filter "label=com.docker.compose.project=$ComposeProjectName" `
                                    --format "{{ .ID }}" `
                                    | Out-String

if (!$?)
{
    Write-Output "##vso[task.LogIssue type=error;]Failed to identify compose services for project: $ComposeProjectName"
    Write-Output "##vso[task.complete result=Failed;]"
    exit 1;
}

Write-Output "Found the following container IDs: $LsCommandOutput"

$LsCommandOutput.Split([System.Environment]::NewLine, [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
    $ContainerId = $_
    $ComposeServiceLabelsAsJson = docker inspect --format '{{ json .Config.Labels }}' `
                                                 "$ContainerId" `
                                                 | Out-String `
                                                 | ConvertFrom-Json

    if (!$?)
    {
        Write-Output "##vso[task.LogIssue type=error;]Failed to inspect container with ID: $ContainerId"
        Write-Output "##vso[task.complete result=Failed;]"
        exit 2;
    }

    $ComposeServiceNameLabel = 'com.docker.compose.service'
    $ComposeServiceName = $ComposeServiceLabelsAsJson.$ComposeServiceNameLabel
    $LogFileName = "$ComposeProjectName--$ComposeServiceName--$ContainerId.log"
    $LogFilePath = Join-Path -Path $LogsOutputFolder $LogFileName

    $PublishLogsInfoMessage = "About to publish logs for compose service with container id: " `
                            + "`"$($ComposeService.ContainerId)`" and service name: " `
                            + "`"$($ComposeService.ServiceName)`" to file: `"$LogFilePath`" ..."
    Write-Output $PublishLogsInfoMessage

    if (![System.IO.File]::Exists($LogsOutputFolder))
    {
       New-Item -Path "$LogsOutputFolder" -ItemType "Directory"
    }

    docker logs --tail "all" `
                --details `
                "$ContainerId" `
                | Out-File -Force -FilePath "$LogFilePath"

    if (!$?)
    {
        Write-Output "##vso[task.LogIssue type=error;]Failed to fetch logs for container with ID: $ContainerId"
        Write-Output "##vso[task.complete result=Failed;]"
        exit 3;
    }
}

exit 0;