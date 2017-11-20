local composer = require( "composer" )

local scene = composer.newScene()

local tiled = require "com.ponywolf.ponytiled"

local json = require "json"

local sceneTransition = require "sceneTransition"

local listenersModule = require "listeners"

-- -----------------------------------------------------------------------------------
-- Declaração das variáveis
-- -----------------------------------------------------------------------------------
local menu

local newGameButton

local playButton

local fitScreen = require "fitScreen"

local listeners = listenersModule:new()

-- -----------------------------------------------------------------------------------
-- Cenas
-- -----------------------------------------------------------------------------------
-- create()
function scene:create( event )

	local sceneGroup = self.view
	-- Code here runs when the scene is first created but has not yet appeared on screen

	display.setDefault("magTextureFilter", "nearest")
  	display.setDefault("minTextureFilter", "nearest")
	local menuData = json.decodeFile(system.pathForFile("tiled/menu.json", system.ResourceDirectory))  -- load from json export

	menu = tiled.new(menuData, "tiled")

	newGameButton = menu:findObject("new game")
	playButton = menu:findObject("play")
	title = menu:findObject("title")

	sceneGroup:insert( menu )

	fitScreen.fitMenu( menu, newGameButton, playButton, title )

	listeners:add( playButton, "tap",  sceneTransition.gotoChooseGameFile )
	listeners:add( newGameButton, "tap", sceneTransition.gotoNewGame )
end


-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		

	elseif ( phase == "did" ) then
		
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		listeners:destroy()
	elseif ( phase == "did" ) then
		menu:removeSelf()
		composer.removeScene( "menu" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	-- Code here runs prior to the removal of scene's view

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
