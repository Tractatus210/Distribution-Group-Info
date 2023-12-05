function MessageTrace-Test {

    param(
        [bool]$pass_onto_next
    )
    
    $now = Get-Date
    $30_days_ago = $now.AddDays(-30)
    $60_days_ago = $now.AddDays(-60)

    $dist_groups_original = Get-DistributionGroup -ResultSize Unlimited | Select-Object -ExpandProperty PrimarySmtpAddress

    $dist_groups_random = Get-Random -InputObject $dist_groups_original -Count 20

    $dist_groups_working = $dist_groups_random

    $active_in_last_30_days = @()
    $active_in_last_60_days = @()
    $probably_not_active = @()

    function FindMessages {
        param (
            $start,
            $end,
            $group_to_check
        )

        $messages_found = Get-MessageTrackingLog -Recipients $group_to_check -Start $start -End $end -ResultSize Unlimited

        return $messages_found
    }
        
    #check for groups active in last 30 days
    $dist_groups_working | ForEach-Object{
        $found = FindMessages -start $30_days_ago -end $now -group_to_check $_
        if($found.Count -gt 0){
            $active_in_last_30_days += $_
        }
    }

    $dist_groups_working = $dist_groups_working | Where-Object {$_ -notin $active_in_last_30_days}

    #check for groups active in last 60 days but not last 30
    $dist_groups_working | ForEach-Object{
        $found = FindMessages -start $60_days_ago -end $30_days_ago -group_to_check $_
        if($found.Count -gt 0){
            $active_in_last_60_days += $_
        }
    }

    $dist_groups_working = $dist_groups_working | Where-Object {$_ -notin $active_in_last_60_days}

    Write-Output "The total number of distribution groups checked is 20"

    Write-Output "A total of ${active_in_last_30_days.count} distribution groups have received email in the last 30 days and are likely still active:"
    echo $active_in_last_30_days

    Write-Output "A total of ${active_in_last_60_days.count}  distribution groups have last recieved email between 30 and 60 days ago and may or may not still be active:"
    echo $active_in_last_60_days

    Write-Output "A total of ${dist_groups_working.count} distribution groups haven't received an email in the last 60 days and are likely inactive"

    if($pass_onto_next -eq $true){
        return $dist_groups_random
    }
}

while($true){
    MessageTrace-Test -pass_onto_next $false
    $test_again = Read-Host "Press y to run the test again with 20 more random distribution groups"
    if($test_again -ne "y" -and $test_again -ne "Y"){
        break
    }

}

# get members of groups and sort by number of members

function Get-GroupMemberInfo {
    param (
        $list_of_groups
    )
    
    $group_info = @()

    foreach($group in $list_of_groups){
        $members = Get-DistributionGroupMember -Identity $group | Select-Object -ExpandProperty PrimarySmtpAddress
        $info = New-Object pscustomobject -Property @{
            GroupEmail = $group
            MemberCount = $members.Count
            Members = $members
        }
        
        $group_info += $info
    }

    $sorted_groups = $group_info | Sort-Object MemberCount

    return $sorted_groups
}

"Now we've established that it finds emails for the groups, we can test that it collects the info about each group properly"

$groups_to_test = MessageTrace-Test -pass_onto_next $true
$groups_sorted = Get-GroupMemberInfo -list_of_groups $groups_to_test

0..4 | ForEach-Object{
    $iter = ($_ + 1).ToString()
    Write-Output "Testing $iter of 5"
    Write-Output "Distribution group email:"
    Write-Output $groups_sorted[$_].GroupEmail
    Write-Output "Group member count:"
    Write-Output $groups_sorted[$_].MemberCount
    Write-Output "Group members:"
    Write-Output $groups_sorted[$_].Members
}


