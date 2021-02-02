#requires -module @{ModuleName = 'Az.Accounts'; ModuleVersion = '1.5.2'}
#requires -version 6.2

function Get-AzSentinelIncident {
    <#
    .SYNOPSIS
    Get Azure Sentinel Incident
    .DESCRIPTION
    With this function you can get a list of open incidents from Azure Sentinel.
    You can can also filter to Incident with speciefiek case namber or Case name
    .PARAMETER SubscriptionId
    Enter the subscription ID, if no subscription ID is provided then current AZContext subscription will be used
    .PARAMETER WorkspaceName
    Enter the Workspace name
    .PARAMETER IncidentName
    Enter incident name, this is the same name as the alert rule that triggered the incident
    .PARAMETER CaseNumber
    Enter the case number to get specfiek details of a open case
    .PARAMETER All
    Use -All switch to get a list of all the incidents
    .EXAMPLE
    Get-AzSentinelIncident -WorkspaceName ""
    Get a list of the last 200 Incidents
    .EXAMPLE
    Get-AzSentinelIncident -WorkspaceName "" -All
    Get a list of all Incidents
    .EXAMPLE
    Get-AzSentinelIncident -WorkspaceName "" -incidentNumber
    Get information of a specifiek incident with providing the incidentNumber
    .EXAMPLE
    Get-AzSentinelIncident -WorkspaceName "" -IncidentName "", ""
    Get information of one or more incidents with providing a incident name, this is the name of the alert rule that triggered the incident
    #>

    [cmdletbinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false,
            ParameterSetName = "Sub")]
        [ValidateNotNullOrEmpty()]
        [string] $SubscriptionId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceName,

        [Parameter(Mandatory = $false,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter(Mandatory = $false,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Title,

        [Parameter(Mandatory = $false,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int[]]$IncidentNumber,

        [Parameter(Mandatory = $false,
            ValueFromPipeline)]
        [Switch]$All,

        [Parameter(Mandatory = $false,
            ValueFromPipeline)]
        [Switch]$Preview
    )

    begin {
        precheck
    }

    process {
        switch ($PsCmdlet.ParameterSetName) {
            Sub {
                $arguments = @{
                    WorkspaceName  = $WorkspaceName
                    SubscriptionId = $SubscriptionId
                }
            }
            default {
                $arguments = @{
                    WorkspaceName = $WorkspaceName
                }
            }
        }

        try {
            Get-LogAnalyticWorkspace @arguments -ErrorAction Stop
        }
        catch {
            Write-Error $_.Exception.Message
            break
        }

        if($Preview) {
            $uri = "$script:baseUri/providers/Microsoft.SecurityInsights/incidents?api-version=2019-01-01-preview"
        }
        else {
            $uri = "$script:baseUri/providers/Microsoft.SecurityInsights/incidents?api-version=2020-01-01"
        }

        Write-Verbose -Message "Using URI: $($uri)"

        try {
            $incidentRaw = (Invoke-RestMethod -Uri $uri -Method Get -Headers $script:authHeader)

            $incident += $incidentRaw.value

            if ($All) {
                while ($incidentRaw.nextLink) {
                    $incidentRaw = (Invoke-RestMethod -Uri $($incidentRaw.nextLink) -Headers $script:authHeader -Method Get)
                    $incident += $incidentRaw.value
                }
            }
        }
        catch {
            Write-Verbose $_
            Write-Error "Unable to get incidents with error code: $($_.Exception.Message)" -ErrorAction Stop
        }

        $return = @()

        if ($incident) {
            Write-Verbose "Found $($incident.count) incidents"

            if ($Name.Count -ge 1) {
                foreach ($rule in $Name) {
                    [PSCustomObject]$temp = $incident | Where-Object { $_.properties.name -like $rule }

                    if ($null -ne $temp) {
                        $temp.properties | Add-Member -NotePropertyName etag -NotePropertyValue $temp.etag -Force
                        $temp.properties | Add-Member -NotePropertyName name -NotePropertyValue $temp.name -Force
                        $return += $temp.properties
                    }
                    else {
                        Write-Error "Unable to find incident: $rule"
                    }
                }
            }
            elseif ($title.Count -ge 1) {
                foreach ($rule in $title) {
                    [PSCustomObject]$temp = $incident | Where-Object { $_.properties.title -eq $rule }

                    if ($null -ne $temp) {
                        $temp.properties | Add-Member -NotePropertyName etag -NotePropertyValue $temp.etag -Force
                        $temp.properties | Add-Member -NotePropertyName name -NotePropertyValue $temp.name -Force
                        $return += $temp.properties
                    }
                    else {
                        Write-Error "Unable to find incident: $rule"
                    }
                }
            }
            elseif ($incidentNumber.Count -ge 1) {
                foreach ($rule in $incidentNumber) {
                    [PSCustomObject]$temp = $incident | Where-Object { $_.properties.incidentNumber -eq $rule }

                    if ($null -ne $temp) {
                        $temp.properties | Add-Member -NotePropertyName etag -NotePropertyValue $temp.etag -Force
                        $temp.properties | Add-Member -NotePropertyName name -NotePropertyValue $temp.name -Force
                        $return += $temp.properties
                    }
                    else {
                        Write-Error "Unable to find incident: $rule"
                    }
                }
                return $return
            }
            else {
                $incident | ForEach-Object {
                    $_.properties | Add-Member -NotePropertyName etag -NotePropertyValue $_.etag -Force
                    $_.properties | Add-Member -NotePropertyName name -NotePropertyValue $_.name -Force
                }
                $return += $incident.properties
            }
            return $return
        }
        else {
            Write-Warning "No incident found on $($WorkspaceName)"
        }
    }
}
