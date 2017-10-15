local composer = require( "composer" )

local tiled = require "com.ponywolf.ponytiled"

local json = require "json"

local persistence = require "persistence"

local scene = composer.newScene()

local scenesTransitions = require "scenesTransitions"

local fitScreen = require "fitScreen"

-- -----------------------------------------------------------------------------------
-- Declaração das variáveis
-- -----------------------------------------------------------------------------------
local goBackButton

local chooseGameFile

local gameFiles = { box = { }, text = { } }

-- -----------------------------------------------------------------------------------
-- Funções
-- -----------------------------------------------------------------------------------
-- Transfere controle para o gamefile escolhido
local function loadGameFile( event )
	local fileName = event.target.myName
	local gameFile 
	
	persistence.setCurrentFileName( fileName ) 
	gameFile = persistence.loadGameFile( )

	print( "-------------------------------------------------------------------" )
	print( "ARQUIVO ESCOLHIDO: " .. fileName )

	-- Verifica em qual minigame o jogo estava quando foi salvo
	if ( gameFile.currentMiniGame == "map" ) then
		scenesTransitions.gotoMap( )
	elseif ( gameFile.currentMiniGame == "house" ) then
		scenesTransitions.gotoHouse( )
	end 
end

-- Remove os objetos
local function destroyScene( )
  	chooseGameFile:removeSelf( )
	chooseGameFile = nil

	for k, v in pairs( gameFiles.box ) do
		gameFiles.box[k]:removeEventListener( "tap", loadGameFile )
		gameFiles.box[k] = nil 
	end

	for k, v in pairs( gameFiles.text ) do
		gameFiles.text[k] = nil 
	end

	gameFiles = nil 
end

-- -----------------------------------------------------------------------------------
-- Cenas
-- -----------------------------------------------------------------------------------
-- create()
function scene:create( event )
	local sceneGroup = self.view
	
	display.setDefault("magTextureFilter", "nearest")
  	display.setDefault("minTextureFilter", "nearest")
	local chooseGameData = json.decodeFile(system.pathForFile("tiled/chooseGameFile.json", system.ResourceDirectory))  -- load from json export

	chooseGameFile = tiled.new(chooseGameData, "tiled")

	local filesNames = persistence.filesNames()

	local gameFilesLayer = chooseGameFile:findLayer("gameFiles")

	for i = 1, gameFilesLayer.numChildren do
		local text

		table.insert( gameFiles.box, gameFilesLayer[i] )

		if ( ( filesNames ~= nil ) and ( filesNames[i] ~= nil ) ) then
			text = display.newText( chooseGameFile, filesNames[i], gameFilesLayer[i].x, gameFilesLayer[i].y, system.nativeFont, 30 )
			table.insert(gameFiles.text, text ) 
			gameFiles.box[#gameFiles.box].myName = filesNames[i]
			gameFiles.box[#gameFiles.box]:addEventListener( "tap", loadGameFile )
		end 
	end

	goBackButton = chooseGameFile:findObject("goBackButton")

	fitScreen:fitBackground(chooseGameFile)

	sceneGroup:insert( chooseGameFile )
end


-- show()
function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		goBackButton:addEventListener( "tap", scenesTransitions.gotoMenu )
	elseif ( phase == "did" ) then

	end
end


-- hide()
function scene:hide( event )
	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
	elseif ( phase == "did" ) then
		destroyScene( )
		composer.removeScene( "chooseGameFile" )
	end
end


-- destroy()
function scene:destroy( event )
	local sceneGroup = self.view
	goBackButton:removeEventListener( "tap", scenesTransitions.gotoMenu )
	goBackButton = nil
end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene
