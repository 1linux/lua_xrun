-- xrun.lua
-- Version 0.1: Aug.24 2014. First release Helmut Gruber, EBCOM.de
-- Version 0.2: Sep.23 2014. Automatic handling of public key transfer
-- Desc:
-- Copy your local sources to a remote ( ssh ) host and
-- run your application remotely - plus debug locally in your ZeroBraneStudio
--
-- All files in your local ZBS project path are being copied.
-- ssh-public-key is esablished automatically ( just enter password twice, and then never again )

-- Important: start "xrun.lua" in ZBS via F6-key; debugging server has to be active; mobdebug.lua has to be included in your sources.
-- Important2: Don't edit your source files on the remote host - changes are lost on next run.


-- Configure debugging parameters here:

local debugging_peer   = "172.31.255.241"                   -- e.g. my raspberry pi
local debugging_user   = "pi"
local debugging_pwd    = "raspberry"
local debugging_basedir= "/home/"..debugging_user.."/lua"   -- rsync could also do "~/lua", but pscp cannot...
local debugging_main   = "test.lua"                         -- what to run remotely - your main script!

-- Don't change anything below --

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
if ssh_client then -- we are running on the debugging client
  local peer=ssh_client:match("(%d+%.%d+%.%d+%.%d+)")
  require("mobdebug").start(peer); dofile(arg[1])
else -- we are on our developer machine
  local s="cd "..debugging_basedir..";lua xrun.lua "..debugging_main.. ""
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
    
  else -- not windows: Mac or Linux are fine... have ssh installed and ssh-keygen should have been run - surely of you are a developer ;-)
    local i=sh("rsync -avz -e \"ssh -oStrictHostKeyChecking=no \" "..debugging_user.."@"..debugging_peer..":~/.ssh/authorized_keys .") -- Maybe you have to enter a password here...
    local authorized=false
    if file_exists("authorized_keys") then
      local fh=io.open("authorized_keys","r")
      local a=fh:read("*all")
      fh:close()
      fh=io.open(os.getenv("HOME").."/.ssh/id_rsa.pub","r")
      if fh then
        local i=fh:read("*all")
        fh:close()
        local a2,i2=a:gsub("%+",""):gsub("%.",""):gsub("%-",""), i:gsub("%+",""):gsub("%.",""):gsub("%-","")
        if nil==a2:find(i2) then
          fh=io.open("authorized_keys","a")
          fh:write("\n"..i)
          fh:close()
        else
          authorized=true
        end
      end
    else
      i=sh("cp ~/.ssh/id_rsa.pub authorized_keys")
    end
    if not authorized then
      i=sh("rsync -avz authorized_keys "..debugging_user.."@"..debugging_peer..":~/.ssh/authorized_keys") -- maybe you have to enter the password once again here - for the very last time...
    end
    os.remove("authorized_keys") -- we dont need this on the client...
    sh("rsync -avz ./ "..debugging_user.."@"..debugging_peer..":"..debugging_basedir.."/") -- transfer sources
    sh("ssh -oStrictHostKeyChecking=no "..debugging_user.."@"..debugging_peer.." 'cd "..debugging_basedir..";lua xrun.lua "..debugging_main.. "' ") -- run your Lua script  on the remote side
  end
end
