function ansible {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",
        [Parameter(Mandatory=$False)]
        [String]$server = "lemp",
        [Parameter(Mandatory=$False)]
        [String]$invFile = "./yandex_cloud.ini",
        [Parameter(Mandatory=$False)]
        [String]$privateKey = "~/.ssh/morsh_bastion_SSH",
        [Parameter(Mandatory=$False,Position=0)]
        [String]$args
    )
    wsl -d $distr -u $user -e ansible $server --inventory-file "$invFile" --private-key $privateKey $args
} 

Set-Alias ansible-playbook ansiblePlaybook
function ansiblePlaybook {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",        
        [Parameter(Mandatory=$False)]
        [String]$server = "lemp",
        [Parameter(Mandatory=$False)]
        [String]$invFile = "./yandex_cloud.ini",
        [Parameter(Mandatory=$False)]
        [String]$privateKey = "~/.ssh/morsh_bastion_SSH",
        [Parameter(Mandatory=$False)]
        [String]$Playbook = "./provisioning.yaml",
        [Parameter(Mandatory=$False,Position=0)]
        [string]$fileSecrets = '~/.vault_pass',
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$tagInit,
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$tagDrop,
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$secret
    )

    if($secret){$params='-e';$secrets = "'@secrets'"}

    if($tagInit){$params='--tags';$tag = "init postfix"}elseif($tagDrop){$param='--tags';$tag = "drop postfix"}

    wsl -d $distr -u $user -e ansible-playbook  -i "$invFile" --private-key $privateKey $params $secrets --vault-password-file=$fileSecrets  $Playbook  $param $tag
} 

Set-Alias ansible-vault ansibleVault
function ansibleVault {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",
        [Parameter(Mandatory=$False,Position=0)]
        [String]$action = 'encrypt',
        [Parameter(Mandatory=$False,Position=0)]
        [String]$file = 'secrets',
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$ask,
        [Parameter(Mandatory=$False,Position=0)]
        [string]$fileSecrets = '~/.vault_pass'

    )
    
    if($ask){$passwd = "--ask-vault-pass"}

    wsl -d $distr -u $user -e ansible-vault $action --vault-password-file=$fileSecrets $passwd $file
} 



Set-Alias ansible-galaxy ansibleGalaxy
function ansibleGalaxy {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",
        [Parameter(Mandatory=$False,Position=0)]
        [String]$type = 'role',
        [Parameter(Mandatory=$False,Position=0)]
        [String]$action = 'init',
        [Parameter(Mandatory=$False,Position=0)]
        [String]$roleName = 'sample',
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$force

    )
    
    if($force){$f = '--force'}

    wsl -d $distr -u $user -e ansible-galaxy $type $action $roleName $f
} 


function molecule {
    param (
        [Parameter(Mandatory=$False)]
        [string]$role = "nginx",
        [Parameter(Mandatory=$False)]
        [String]$org = "morsh92",
        [switch]$verify,
        [switch]$wipe

    )
    
    $path = (Get-Location).path -replace "\\", "/"
   
    if($wipe){
        docker rm molecule-$role -f
        Remove-Item -Recurse -Force $path/molecule/$role
        }else{

     docker inspect molecule-$role | Out-Null; if($?){
        write-host -f Magenta "Container for such role already exist.To purge use -wipe."
     }else{

     docker run --rm -d --name=molecule-$role `
     -v  $path/molecule:/opt/molecule -v  /sys/fs/cgroup:/sys/fs/cgroup:ro `
     --privileged `
      morsh92/molecule:dind
     }
    

     if(Test-Path -Path $path/molecule/$role) {write-host -f magenta "This role already exist in molecule"}else{
     docker exec -ti molecule-$role  /bin/sh -c  "molecule init role $org.$role -d docker"
     }
     
     try{. $path/$role/required_roles.ps1}catch{"There is no required_roles.ps1 file!"}
     
     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/tasks/* $path/molecule/$role/tasks}catch{write-host -f magenta "There is no folder tasks!"}

     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/handlers/* $path/molecule/$role/handlers}catch{write-host -f magenta "There is no folder handlers!"}

     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/templates/* $path/molecule/$role/templates}catch{write-host -f magenta "There is no folder templates!"}

     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/files/* $path/molecule/$role/files}catch{write-host -f magenta "There is no folder files!"}

     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/tests/* $path/molecule/$role/tests}catch{write-host -f magenta "There is no folder tests!"}

     try{Copy-Item -ErrorAction Stop -Recurse -Force  $path/$role/vars/* $path/molecule/$role/vars}catch{write-host -f magenta "There is no folder vars!"}

     try{Copy-Item  -ErrorAction Stop -Recurse -Force  $path/$role/defaults/* $path/molecule/$role/defaults}catch{write-host -f magenta "There is no folder defaults!"}

     # try{Copy-Item  -ErrorAction Stop -Recurse -Force  $path/$role/meta/* $path/molecule/$role/meta}catch{write-host -f magenta "There is no folder meta!"}
      
     try{$rolereq | ForEach-Object {Copy-Item  -ErrorAction Stop -Recurse -Force  $path/$_ $path/molecule/$role/molecule/default/roles/$_ }}catch{write-host -f magenta "There is no such role folder in Project!"}

     try{Copy-Item   -ErrorAction Stop -Force  $path/$role/verify.yml $path/molecule/$role/molecule/default/verify.yml  }catch{write-host -f magenta "There is no file verify.yml!"}
    
     try{Copy-Item  -ErrorAction Stop -Force  $path/$role/molecule.yml $path/molecule/$role/molecule/default/molecule.yml}catch{write-host -f magenta "There is no file molecule.yml!"}

     docker inspect molecule-$role | Out-Null; if($?){
     docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule converge"
     }else{
     docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule create"
     docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule converge"
     }
    

     if($verify){
     if(!(Test-Path $path/molecule/$role/tests)){mkdir -p $path/molecule/$role/tests}

     Copy-Item -Recurse -Force $path/ansible_tests/* $path/molecule/$role/tests
    
     docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule verify"
     
     }
    }


} 

function prompt {

    #Assign Windows Title Text
    $host.ui.RawUI.WindowTitle = "Current Folder: $pwd"

    #Configure current user, current folder and date outputs
    $CmdPromptCurrentFolder = Split-Path -Path $pwd -Leaf
    $CmdPromptUser = [Security.Principal.WindowsIdentity]::GetCurrent();
    $Date = Get-Date -Format 'dddd hh:mm:ss tt'

    # Test for Admin / Elevated
    $IsAdmin = (New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    #Calculate execution time of last cmd and convert to milliseconds, seconds or minutes
    $LastCommand = Get-History -Count 1
    if ($lastCommand) { $RunTime = ($lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime).TotalSeconds }

    if ($RunTime -ge 60) {
        $ts = [timespan]::fromseconds($RunTime)
        $min, $sec = ($ts.ToString("mm\:ss")).Split(":")
        $ElapsedTime = -join ($min, " min ", $sec, " sec")
    }
    else {
        $ElapsedTime = [math]::Round(($RunTime), 2)
        $ElapsedTime = -join (($ElapsedTime.ToString()), " sec")
    }

    #Decorate the CMD Prompt
    Write-Host ""
    Write-host ($(if ($IsAdmin) { 'Elevated ' } else { '' })) -BackgroundColor DarkRed -ForegroundColor White -NoNewline
    Write-Host " USER:$($CmdPromptUser.Name.split("\")[1]) " -BackgroundColor DarkBlue -ForegroundColor Magenta -NoNewline
    If ($CmdPromptCurrentFolder -like "*:*")
        {Write-Host " $CmdPromptCurrentFolder "  -ForegroundColor White -BackgroundColor DarkGray -NoNewline}
        else {Write-Host ".\$CmdPromptCurrentFolder\ "  -ForegroundColor Green -BackgroundColor DarkGray -NoNewline}

    Write-Host " $date " -ForegroundColor White
    Write-Host "[$elapsedTime] " -NoNewline -ForegroundColor Green
    return "> "
}

function DropWSLVMDockerCache {
    wsl -d docker-desktop -e sh  -c  "echo 3 > /proc/sys/vm/drop_caches"
    
}