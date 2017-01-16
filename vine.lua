dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local items = {}
local discousers = {}
local discovideos = {}
local discotags = {}

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

for item in string.gmatch(item_value, "([^,]+)") do
  items[item] = true
  if item_type == "video" or item_type == "videos" then
    addedtolist["https://vine.co/v/" .. item .. "/card?api=1"] = true
    addedtolist["https://vine.co/v/" .. item .. "/fb-card?audio=1"] = true
    addedtolist["https://vine.co/v/" .. item .. "/embed"] = true
    addedtolist["https://vine.co/v/" .. item] = true
  elseif item_type == "user" then
    addedtolist["https://vine.co/u/" .. item] = true
    addedtolist["https://vine.co/api/users/profiles/" .. item] = true
    addedtolist["https://vine.co/api/timelines/users/" .. item] = true
    addedtolist["https://vine.co/api/timelines/users/" .. item .. "/likes"] = true
  end
end

load_json_file = function(file)
  if file then
    return JSON:decode(file)
  else
    return nil
  end
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

allowed = function(url)
  if string.match(url, "^https?://[^/]*vine%.co/v/[0-9A-Za-z]+") then
    discovideos[string.match(url, "^https?://[^/]*vine%.co/v/([0-9A-Za-z]+)")] = true
  elseif string.match(url, "^https?://[^/]*vine%.co/u/[0-9]+") then
    discousers[string.match(url, "^https?://[^/]*vine%.co/u/([0-9]+)")] = true
  elseif string.match(url, "^https?://[^/]*vine%.co/tags/.+") then
    discotags[string.match(url, "^https?://[^/]*vine%.co/tags/(.+)")] = true
  end

  if string.match(url, "^https?://[^%.]+%.twimg%.com/") then
    return true
  end

  if string.match(url, "'+")
     or string.match(url, "[<>\\]")
     or string.match(url, "//$") then
    return false
  end

  if item_type == 'video' or item_type == 'videos' then
    if string.match(url, "^https?://[^/]*cdn%.vine%.co/")
       and not string.match(url, "^https?://v%.cdn%.vine%.co/[rv]/avatars/") then
      return true
    end
  elseif item_type == 'user' then
    if string.match(url, "^https?://[^/]*cdn%.vine%.co/[rw]/")
       and not (string.match(url, "^https?://[^/]*cdn%.vine%.co/r/video")
        or string.match(url, "^https?://[^/]*cdn%.vine%.co/r/thumbs/")
        or string.match(url, "^https?://[^/]*cdn%.vine%.co/r/avatars/")) then
      return true
    end
  end


  for s in string.gmatch(url, "([0-9a-zA-Z%.%-_%%]+)") do
    if items[s] == true
       and string.match(url, "^https?://[^/]*vine%.co") then
      return true
    end
  end

  for s in string.gmatch(url, "([^/%?=&]+)") do
    if items[s] == true
       and string.match(url, "^https?://[^/]*vine%.co") then
      return true
    end
  end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true)
     and (allowed(url) or html == 0)
     and not string.match(url, "^https?://[^/]*cdn%.vine%.co/r/avatars/") then
    addedtolist[url] = true
    return true
  else
    return false
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    if string.match(url, "^https?://[^/]*cdn%.vine%.co/r/") then
      url = string.gsub(url, "https?://", "https://")
    end
    if (downloaded[url] ~= true and addedtolist[url] ~= true)
       and allowed(url) then
      table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
      addedtolist[url] = true
      addedtolist[string.gsub(url, "&amp;", "&")] = true
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/\\/") then
      check(string.match(url, "^(https?:)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(string.match(url, "^(https?:)")..newurl)
    elseif string.match(newurl, "^\\/") then
      check(string.match(url, "^(https?://[^/]+)")..string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(string.match(url, "^(https?://[^%?]+)")..newurl)
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?")
        or string.match(newurl, "^[/\\]")
        or string.match(newurl, "^[jJ]ava[sS]cript:")
        or string.match(newurl, "^[mM]ail[tT]o:")
        or string.match(newurl, "^vine:")
        or string.match(newurl, "^android%-app:")
        or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end
  
  if allowed(url)
     and not (string.match(url, "^https?://[^/]*cdn%.vine%.co/r/")
      or string.match(url, "^https?://[^/]*cdn%.vine%.co/video")
      or string.match(url, "%.ts$")
      or string.match(url, "^https?://pbs%.twimg%.com/")) then
    html = read_file(file)

    if string.match(url, "%.m3u8$") then
      check(url .. "?network_type=wifi")
      for s in string.gmatch(html, "[^%s]+") do
        if not string.match(s, "^#") then
          checknewurl(s)
        end
      end
    end

    for s in string.gmatch(html, '"longformId[^"]*"%s*:%s*"([0-9]+)"') do
      items[s] = true
      check("https://vine.co/watch/" .. s)
      check("https://vine.co/api/longforms/" .. s .. "/endlessLikes")
    end

    for newuser in string.gmatch(html, '"user[iI]d[^"]*"%s*:%s*"?([0-9]+)"?') do
      discousers[newuser] = true
    end

    for newtag in string.gmatch(html, 'tags?\\?/([^"]+)"') do
      discotags[newtag] = true
    end

    for newtag in string.gmatch(html, '{[^}]*"title"%s*:%s*"([^"]+)"[^}]+"type"%s*:%s*"tag"[^}]*}') do
      discotags[newtag] = true
    end

    if string.match(url, "^https?://[^/]*vine%.co/v/[0-9a-zA-Z]+$")
       and string.match(html, 'content="vine://post/[0-9]+"') then
      local postid = string.match(html, 'content="vine://post/([0-9]+)"')
      items[postid] = true
      check("https://vine.co/api/posts/" .. postid .. "/comments?page=1&size=3")
      check("https://vine.co/api/posts/" .. postid .. "/comments?page=1&size=100")
      check("https://vine.co/api/posts/" .. postid .. "/comments?page=0&size=3")
      check("https://vine.co/api/posts/" .. postid .. "/comments?page=0&size=100")
    end

    if string.match(url, "^https?://[^/]*vine%.co/api/") and status_code == 200 then
      local json_ = load_json_file(html)
      if json_["success"] ~= true then
        io.stdout:write("Getting information from API was unsuccesful. ABORTING...\n")
        abortgrab = true
      end
    end      

    if (item_type == "video" or item_type == "videos")
       and string.match(url, "^https?://[^/]*vine%.co/api/posts/[0-9]+/comments%?page=[0-9]+&size=[0-9]+") then
      local json_ = load_json_file(html)
      if json_["data"]["nextPage"] ~= nil then
        local page = tostring(json_["data"]["nextPage"])
        local size = tostring(json_["data"]["size"])
        local postid = string.match(url, "^https?://[^/]*vine%.co/api/posts/([0-9]+)/comments%?page=[0-9]+&size=[0-9]+")
        check("https://vine.co/api/posts/" .. postid .. "/comments?page=" .. page .. "&size=" .. size)
      end
    end

    if item_type == "user"
       and string.match(url, "^https?://[^/]*vine%.co/u/[0-9]+$") then
      local username = string.match(html, '<meta%s+property="og:url"%s+content="https?://[^/]*vine%.co/([^"]+)">')

      if string.match(username, "/")
         and not string.match(username, "^u/") then
        abortgrab = true
      end

      items[username] = true
      check("https://vine.co/" .. username)
      check("https://vine.co/" .. username .. "?mode=grid")
      check("https://vine.co/" .. username .. "?mode=list")
      check("https://vine.co/" .. username .. "?mode=tv")
      check("https://vine.co/" .. username .. "/likes")
      check("https://vine.co/" .. username .. "/likes?mode=grid")
      check("https://vine.co/" .. username .. "/likes?mode=list")
      check("https://vine.co/" .. username .. "/likes?mode=tv")
      check("https://vine.co/api/users/profiles/vanity/" .. username)
      table.insert(urls, { url=string.match(html, '<meta%s+property="og:image"%s+content="([^"]+)">') })
    end

    if (item_type == "user" or item_type == "tag")
       and (string.match(url, "^https?://[^/]*vine%.co/api/timelines/users/[0-9]+")
        or string.match(url, "https?://[^/]*vine%.co/api/timelines/tags/")) then
      local json_ = load_json_file(html)
      if json_["data"]["nextPage"] ~= nil then
        local page = tostring(json_["data"]["nextPage"])
        local anchor = json_["data"]["anchorStr"]
        local size = tostring(json_["data"]["size"])
        check(string.match(url, "^(https?://[^%?]+)") .. "?page=" .. page .. "&anchor=" .. anchor .. "&size=" .. size)
      end
    end

    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 410) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"]) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.exits.IO_FAIL
  end
  return exit_status
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local file = io.open(item_dir..'/'..warc_file_base..'_data.txt', 'w')
  for user, _ in pairs(discousers) do
    file:write("user:" .. user .. "\n")
  end
  for video, _ in pairs(discovideos) do
    file:write("video:" .. video .. "\n")
  end
  for tag, _ in pairs(discotags) do
    file:write("tag:" .. tag .. "\n")
  end
  file:close()
end