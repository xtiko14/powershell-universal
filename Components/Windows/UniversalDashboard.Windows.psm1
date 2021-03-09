function New-UDServiceTable 
{
    <#
    .SYNOPSIS
    Creates a table that displays service status.
    
    .DESCRIPTION
    Creates a table that displays service status. Services can be started and stopped.
    
    .EXAMPLE
    New-UDServiceTable
    #>
    $Columns = @(
        New-UDTableColumn -Title 'Name' -Property 'Name'
        New-UDTableColumn -Title 'Description' -Property 'Description'
        New-UDTableColumn -Title 'Status' -Property 'Status'
        New-UDTableColumn -Title 'Actions' -Property 'Actions' -Render {
            if ($EventData.Status -eq 'Running')
            {
                New-UDButton -Text "Stop" -OnClick { 
                    try 
                    {
                        Stop-Service $EventData.Name -ErrorAction stop
                        Show-UDToast -Message "Stopping service $($EventData.Name)"
                        Sync-UDElement -Id 'serviceTable'
                    }
                    catch 
                    {
                        Show-UDToast -Message "Failed to stop service. $_" -BackgroundColor 'red' -Duration 5000 -MessageColor 'white'
                    }
                } -Icon (New-UDIcon -Icon stop)
            }
            else
            {
                New-UDButton -Text "Start" -OnClick { 
                    try
                    {
                        Start-Service $EventData.Name -ErrorAction stop
                        Show-UDToast -Message "Starting service $($EventData.Name)"
                        Sync-UDElement -Id 'serviceTable'
                    }
                    catch
                    {
                        Show-UDToast -Message "Failed to start service. $_" -BackgroundColor 'red' -Duration 5000 -MessageColor 'white'

                    }

                } -Icon (New-UDIcon -Icon play)
            }
            
        }
    )

    New-UDDynamic -Id 'serviceTable' -Content {
        $Services = Get-Service 
        New-UDTable -Columns $Columns -Data $Services -Paging -Sort
    } -LoadingComponent {
        New-UDSkeleton 
    }
}

function ConvertTo-ByteString {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $byteCount
    )

    Process {
        $suf = @( "B", "KB", "MB", "GB", "TB", "PB", "EB" )
        if ($byteCount -eq 0)
        {
            return "0" + $suf[0];
        }
            
        $bytes = [Math]::Abs($byteCount);
        $place = [Convert]::ToInt32([Math]::Floor([Math]::Log($bytes, 1024)))
        $num = [Math]::Round($bytes / [Math]::Pow(1024, $place), 1)
        return ([Math]::Sign($byteCount) * $num).ToString() + $suf[$place]
    }

}

function New-UDProcessTable 
{
    <#
    .SYNOPSIS
    Creates a table that displays process information.
    
    .DESCRIPTION
    Creates a table that displays process information. The table is has pagination enabled and can be sorted and searched.
    
    .EXAMPLE
    New-UDProcessTable
    #>
    $Columns = @(
        New-UDTableColumn -Title 'Id' -Property 'ID'
        New-UDTableColumn -Title 'Name' -Property 'ProcessName'
        New-UDTableColumn -Title 'CPU' -Property 'CPU'
        New-UDTableColumn -Title 'WorkingSet' -Property 'WorkingSet' -Render {
            $EventData.WorkingSet | ConvertTo-ByteString
        }
    )
    $Processes = Get-Process | Select-Object @("Id", "ProcessName", "CPU", "WorkingSet")
    New-UDTable -Columns $Columns -Data $Processes -Paging -Sort -Search
}

function New-UDEventLogTable {
    <#
    .SYNOPSIS
    Creates a Windows Event Log table.
    
    .DESCRIPTION
    Creates a Windows Event Log table.
    
    .EXAMPLE
    New-UDEventLogTable
    
    Creates a Windows Event Log table.
    #>
    $Columns = @(
        New-UDTableColumn -Property EntryType -Title "Level" -ShowFilter -FilterType select
        New-UDTableColumn -Property TimeWritten -Title "Date and Time"
        New-UDTableColumn -Property Source -Title "Source"  -ShowFilter -FilterType select
        New-UDTableColumn -Property EventId -Title "EventId" -ShowFilter 
        New-UDTableColumn -Property Category -Title "Category"
        New-UDTableColumn -Property Message -Title "Message" -Truncate -Width 400 -ShowFilter 
        New-UDTableColumn -Property Action -Title "" -Render {
            New-UDButton -Text 'View Message' -OnClick {
                Show-UDModal -Content {
                    $EventData.message
                }
            }
        }
    )

    $Sources = Get-WmiObject -Class Win32_NTEventLOgFile | 
        Select-Object FileName, Sources | 
        ForEach-Object -Begin { $hash = @{}} -Process { $hash[$_.FileName] = $_.Sources } -end { $Hash }

    New-UDSelect -Option {
        $Sources.Keys | Sort-Object | ForEach-Object {
            New-UDSelectOption -Name $_ -Value $_
        }
    } -OnChange {
        $Session:LogName = $EventData
        Sync-UDElement -Id 'eventLogTable'
    }

    New-UDDynamic -Id 'eventLogTable' -Content {
        if ($null -eq $Session:LogName)
        {
            $Session:LogName = "Application"
        }

        $Data = Get-EventLog -Newest 100 -LogName $Session:LogName | Select-Object EntryType, TimeWritten, Source, EventId, Category, Message
        New-UDTable -Data $Data -Columns $Columns -ShowSort -ShowFilter
    } -LoadingComponent {
        New-UDSkeleton
        New-UDSkeleton
        New-UDSkeleton
        New-UDSkeleton
    }
}
