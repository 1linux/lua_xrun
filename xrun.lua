-- xrun.lua
-- 24.8.2014 Helmut Gruber, EBCOM.de
-- Released under the MIT Licence
-- Version: 0.1
-- lokales Repository auf Remote Host syncen und
-- dann remote Anwendung starten + lokal in ZBS debuggen
-- Es werden alle Files im aktuellen Verzeichnis auf den 
-- remote Host kopiert.
-- Voraussetzung ist ein funktionierendes automatisches
-- ssh-Login mit Key unter Linux/Mac, unter Windows wird putty automatisch geladen.
--
-- Wichtig: xrun.lua im ZBS mit F6 starten; Debugger Server muss aktiv sein; mobdebug.lua muss verfügbar sein (z.B. im lokalen Verzeichnis)

-- Hier Debugging-Parameter konfigurieren
local debugging_peer="192.168.178.45"    -- banana pi
local debugging_user="pi"
local debugging_pwd="raspberry"
local debugging_basedir="/home/"..debugging_user.."/lua"
local debugging_main="test.lua"

-- Ab hier nichts mehr aendern...

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
if ssh_client then
  local peer=ssh_client:match("(%d+%.%d+%.%d+%.%d+)")
  require("mobdebug").start(peer); dofile(arg[1])
else
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
    
  else
    sh("rsync -avz ./ "..debugging_user.."@"..debugging_peer..":"..debugging_basedir.."/")
    sh("ssh "..debugging_user.."@"..debugging_peer.." 'cd "..debugging_basedir..";lua xrun.lua "..debugging_main.. "' ")
  end
end
