function Test-TbPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Leaf', 'Container', 'Any')]
        [string]$PathType = 'Any'
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    switch ($PathType) {
        'Leaf'      { return (Test-Path $Path -PathType Leaf) }
        'Container' { return (Test-Path $Path -PathType Container) }
        'Any'       { return (Test-Path $Path) }
    }
}
