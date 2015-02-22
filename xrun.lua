-- xrun.lua
-- Version 0.1: Aug.24 2014. First release Helmut Gruber, EBCOM.de
-- Version 0.2: Sep.23 2014. Automatic handling of public key transfer
-- Version 0.3: Variable xrun script name, luajit support
-- Desc:
-- Copy your local sources to a remote ( ssh ) host and
-- run your application remotely - plus debug locally in your ZeroBraneStudio
-- 
-- All files in your local ZBS project path are being copied.
-- ssh-public-key is esablished automatically ( just enter password twice, and then never again )
-- Important: start "xrun.lua" in ZBS via F6-key; debugging server has to be active; mobdebug.lua has to be included in your sources.
-- Important2: Don't edit your source files on the remote host - changes are lost on next run.

-- Configure debugging parameters here:
local debugging_peer="raspberrypi" 												-- e.g. my raspberry pi
local debugging_user="pi"
local debugging_pwd="raspberry"
local debugging_basedir="/home/"..debugging_user.."/lua"
local debugging_main="ultrasonic_test.lua"									-- what to run remotely - your main script!

-- Some options
local LUA="luajit"								-- lua or luajit

-- Don't change anything below --
local info = debug.getinfo(1,'S');
local XRUN=info.source:sub(2):match(".*/(.*%.lua)$") or info.source:sub(2)
local PUTTY_URL='http://the.earth.li/~sgtatham/putty/latest/x86/putty.exe'
local PSCP_URL='http://the.earth.li/~sgtatham/putty/latest/x86/pscp.exe'
local PLINK_URL='http://the.earth.li/~sgtatham/putty/latest/x86/plink.exe'

local on_windows=(package.config:sub(1,1)=="\\")

local os=require"os"

local function sh(cmd)
  print(cmd)
  local i=os.execute(cmd)
  return i
end

local function file_exists(filename)
  local f=io.open(filename,'r')
  if f then
    f:close()
    return true
  end
end

function check_ssl_key()
	if file_exists("~/.ssh/id_rsa.pub") then
		sh("scp ~/.ssh/id_rsa.pub "..debugging_user.."@"..debugging_peer..":.ssh/tmp")
	end
end

local function download(url,save_as)
  local ltn12=require"ltn12"
  local http=require"socket.http"
  local file=ltn12.sink.file(io.open(save_as,'wb')) 
  http.request{url=url, sink=file}
end

if on_windows then
  if not file_exists("bin/putty.exe") then
    os.execute("mkdir bin")
    download(PUTTY_URL,'bin\\putty.exe')
    download(PSCP_URL,'bin\\pscp.exe')
    download(PLINK_URL,'bin\\plink.exe')
  end
end

local ssh_client=os.getenv("SSH_CLIENT")
if ssh_client then
  local peer=ssh_client:match("(%d+%.%d+%.%d+%.%d+)")
  require("mobdebug").start(peer); dofile(arg[1])
else
  local s="cd "..debugging_basedir..";"..LUA.." "..XRUN.." "..debugging_main.. ""
  if on_windows then
    local r=sh("bin\\plink.exe "..debugging_peer.." -batch -l "..debugging_user.." -pw "..debugging_pwd.." mkdir -p "..debugging_basedir )
    if r~=0 then
      -- User muss PGP Key akzeptieren
      print("Please check Host Key and run again...")
      sh("bin\\putty.exe "..debugging_user.."@"..debugging_peer)
      os.exit(r)
    else
      r=sh("bin\\pscp.exe -batch -r -pw "..debugging_pwd.." *.* "..debugging_user.."@"..debugging_peer..":"..debugging_basedir.."/")
      if r~=0 then
        print("Error copying Files!")
        os.exit(r)
      else
        r=sh("bin\\plink.exe "..debugging_peer.." -batch -l "..debugging_user.." -pw "..debugging_pwd.." "..s )
      end
    end
    
  else -- not on windows
	check_ssl_key()  
    sh("rsync -avz ./ "..debugging_user.."@"..debugging_peer..":"..debugging_basedir.."/")
    sh("ssh "..debugging_user.."@"..debugging_peer.." 'cd "..debugging_basedir..";"..LUA.." "..XRUN.." "..debugging_main.. "' ")
  end
end
