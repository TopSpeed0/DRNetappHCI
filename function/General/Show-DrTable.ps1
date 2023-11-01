# show Table
 
function Show-DrTable {
    param (
        $table
        #$PropertyObjects
    )
    $string =  $table | Format-Table -AutoSize | Out-String
    $PropertyObjects = (($string -split '\n')[1]).replace(" ",",")
    $PropertySpace = (($string -split '\n')[2]).replace(" ",",")
    $PropertyObjects = $PropertyObjects.split(",").trim()-ne ""
    $PropertySpace = $PropertySpace.split(",").trim()-ne ""
    $table = $table | Select-Object $PropertyObjects
    $index = 0
    $table | Select-Object -First 1|  Foreach-Object {
        $Properties = $_.PSObject.Properties
        write-host "         " -NoNewline
        foreach ( $property in $Properties )
        {    
            # $property = $property
            if ( $index -lt $PropertySpace.Count)  {
                write-host "$($property.name)$(($PropertySpace[$index]).Replace("-"," "))" -f green -NoNewline
            } else {
                write-host "  $($property.name)" -f green -NoNewline
            }
            $index++
        }
    }
    $table | Select-Object "        ",* | Format-Table -HideTableHeaders -AutoSize
} 

function Show-TableString {
    param (
        $table
        #$PropertyObjects
    )
    $string =  $table | Format-Table -AutoSize | Out-String
    $string | Select-Object "        ",* | Format-Table -HideTableHeaders -AutoSize
}

function Set-TableSpace {
    param (
        $tableString
    )
    $tableString = $tableString | Format-Table -AutoSize | Out-String
    $tableString = $tableString.trim()

 #table definition
$tabName = "Output table"

#Create Table object
$table = New-Object system.Data.DataTable "$tabName"

#columns definition
$space = New-Object system.Data.DataColumn space,([string])
$col1 = New-Object system.Data.DataColumn col1,([string])

#add columns
$table.Columns.Add($space)
$table.Columns.Add($col1)

    $Measure = $tableString | Measure-Object -Line -Word -Character -IgnoreWhiteSpace
    $x = 1
     for ($i = 0 ; $i -lt $Measure.Lines; $i++ ) {
        #preparation of the row
        $row = $table.NewRow()
        $row.space= "        "
        $row.col1= (($tableString -split '\n')[$i])
        $table.Rows.Add($row)
        $x++
    }
    
#print out the table
$table | Select-Object   space,col1 | format-table -AutoSize -HideTableHeaders
}

