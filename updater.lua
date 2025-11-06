local function getVersion()
	if not fileExists("VERSION") then
		return ""
	end

	local file = fileOpen("VERSION")

	if not file then
		return ""
	end

	local version = fileRead(file, fileGetSize(file))
	fileClose(file)

	return version
end

local function putVersion(version)
	if fileExists("VERSION") then
		fileDelete("VERSION")
	end

	local file = fileCreate("VERSION")
	fileWrite(file, version)
	fileClose(file)
end

local function getChangedFiles(commit, oldSHA, callback)
	fetchRemote("https://api.github.com/repos/TRtam/layta/compare/" .. oldSHA .. "..." .. commit.sha, {}, function(response, info)
		if not info.success then
			outputDebugString("Couldn't compare old sha with current one")
			return
		end

		callback(fromJSON(response).files)
	end)
end

local function downloadFiles(files)
	local queue = {}

	for i = 1, #files do
		local entry = files[i]

		if not fileExists(entry.filename) then
			table.insert(queue, entry)
		else
			local file = fileOpen(entry.filename)

			if not file then
				table.insert(queue, entry)
			else
				local sha = hash("sha1", fileRead(file, fileGetSize(file)))
				fileClose(file)

				if entry.sha ~= sha then
					table.insert(queue, entry)
				end
			end
		end
	end

	for i = 1, #queue do
		local entry = queue[1]

		fetchRemote(entry.raw_url, {}, function(response, info)
			if not info.success then
				outputDebugString("Couldn't fetch '" .. entry.filename .. "' it's raw content")
				return
			end

			if fileExists(entry.filename) then
				fileDelete(entry.filename)
			end

			local file = fileCreate(entry.filename)
			if file then
				fileWrite(file, response)
				fileClose(file)
			end
		end)
	end
end

fetchRemote("https://api.github.com/repos/TRtam/layta/commits/main", {}, function(response, info)
	if not info.success then
		outputDebugString("Couldn't fetch latest version from repo")
		return
	end

	local commit = fromJSON(response)

	if commit.sha ~= getVersion() then
		getChangedFiles(commit, getVersion(), function(files)
			downloadFiles(files)
		end)

		putVersion(commit.sha)
	end
end)
