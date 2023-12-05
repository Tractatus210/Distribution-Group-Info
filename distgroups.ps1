$now = Get-Date
$30_days_ago = $now.AddDays(-30)
$60_days_ago = $now.AddDays(-60)

$dist_groups_original = Get-DistributionGroup -ResultSize Unlimited | Select-Object -ExpandProperty PrimarySmtpAddress



$dist_groups_working = $dist_groups_original

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

Write-Output "A total of ${active_in_last_30_days.count} distribution groups have received email in the last 30 days and are likely still active:"
echo $active_in_last_30_days

Write-Output "A total of ${active_in_last_60_days.count}  distribution groups have last recieved email between 30 and 60 days ago and may or may not still be active:"
echo $active_in_last_60_days

Write-Output "A total of ${dist_groups_working.count} distribution groups haven't received an email in the last 60 days and are likely inactive"


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

function Write-ToTextFile {
    param (
        $member_list,
        $file_path
    )
    
    foreach($group in $member_list){
        Add-Content -Path $file_path -Value "Distribution group: ${group.GroupEmail}"
        Add-Content -Path $file_path -Value $group.Members
        Add-Content -Path $file_path "--------------------------------"
    }   
}

# write members of each group to a text file
$30_days_path = ".\dist-groups-active-last-30-days.txt"
New-Item -Path $30_days_path -ItemType "file" -Force

$30_days_sorted_members = Get-GroupMemberInfo -list_of_groups $active_in_last_30_days

Write-ToTextFile -member_list $30_days_sorted_members -file_path $30_days_path


$60_days_path = ".\dist-groups-active-30-to-60-days.txt"
New-Item -Path $60_days_path -ItemType "file" -Force

$60_days_sorted_members = Get-GroupMemberInfo -list_of_groups $active_in_last_60_days

Write-ToTextFile -member_list $60_days_sorted_members -file_path $60_days_path


$likely_inactive_path = ".\dist-groups-likely-inactive.txt"
New-Item -Path $likely_inactive_path -ItemType "file" -Force

$likely_inactive_sorted_members = Get-GroupMemberInfo -list_of_groups $dist_groups_working

Write-ToTextFile -member_list $likely_inactive_sorted_members -file_path $likely_inactive_path