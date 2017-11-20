local composer = require( "composer" )

local perspective = require("com.perspective.perspective")

local scene = composer.newScene()

local tiled = require "com.ponywolf.ponytiled"

local physics = require "physics"

local json = require "json"

local persistence = require "persistence"

local sceneTransition = require "sceneTransition"

local gamePanel = require "gamePanel"

local instructions = require "instructions"

local gameState = require "gameState"

local path = require "path"

local gameScene = require "gameScene"

local listenersModule = require "listeners"

physics.start()
physics.setGravity( 0, 0 )
local listeners = listenersModule:new()
-- -----------------------------------------------------------------------------------
-- Declaração das variáveis
-- -----------------------------------------------------------------------------------
local camera = perspective.createView()

local map

local character

-- tamanho dos tiles usados no tiled
local tilesSize = 32

local messageBubble

local message = 
{
  teacher = 
  { "Olá! Que bom que sua mãe",
  "deixou que você viesse me ajudar.",
  "Os alunos fizeram uma bagunça",
  "na escola. Venha ver." }


}
-- -----------------------------------------------------------------------------------
-- Funções de criação
-- -----------------------------------------------------------------------------------
-- Prepara a câmera para se mover de acordo com os movimentos do personagem
-- @TODO: Mudar os parâmetros de setCameraOffset e setBounds quando trocarmos o mapa 
local function setCamera()
  local layer
  camera:add( character, 1 )
  camera:add( map, 2 )

  layer = camera:layer(1)

  local mapX, mapY = map:localToContent( 0, 0 )
  layer:setCameraOffset( -98, -35 )

  layer = camera:layer(2)
  layer:setCameraOffset( -98, -35 )

  camera:setBounds( 170, 300, 150, 312 )
  camera:setFocus(character)
  camera:track()
  camera:toBack()
end

local function gotoNextLevel()
  local executeButton = gamePanel.tiled:findObject( "executeButton" )

  transition.fadeOut( gamePanel.tiled, { time = 800 } )
  if ( ( gameFileData.house.isComplete == true ) and ( gameFileData.school.isComplete == false ) ) then 
      teacher.xScale = 1
      transition.to( character, { time = 100, x = character.x + 5 } )
      transition.to( teacher, { time = 100, x = teacher.x + 5, onComplete = sceneTransition.gotoSchool } )
      
      if ( ( executeButton.executionsCount == 1 ) and ( executeButton.instructionsCount[#executeButton.instructionsCount] == 3 ) ) then
        gameFileData.school.previousStars = 3
      elseif ( gamePanel.bikeWheel.maxCount == 0 ) then
        gameFileData.school.previousStars = 2
      else 
        gameFileData.school.previousStars = 1
      end

  end 
end

-- -----------------------------------------------------------------------------------
-- Funções que mostram texto
-- -----------------------------------------------------------------------------------
local function showSubText( event )
    messageBubble = event.target

    if ( messageBubble.message[messageBubble.shownText] ) then 
      messageBubble.text:removeSelf()
      messageBubble.options.text = messageBubble.message[messageBubble.shownText]

      local newText = display.newText( messageBubble.options ) 
      newText.x = newText.x + newText.width/2
      newText.y = newText.y + newText.height/2

      messageBubble.text = newText
      messageBubble.shownText = messageBubble.shownText + 1

      messageBubble.blinkingDart.x = messageBubble.x + 33
      messageBubble.blinkingDart.y = messageBubble.y + 12 

    else
      transition.fadeOut( messageBubble.text, { time = 400 } )
      transition.fadeOut( messageBubble, { time = 400, onComplete = gotoNextLevel } )
      messageBubble.text:removeSelf()
      messageBubble.text = nil
      listeners:remove( messageBubble, "tap", showSubText )

      transition.cancel( messageBubble.blinkingDart )
      messageBubble.blinkingDart.alpha = 0
      messageBubble.blinkingDart = nil
    end

    return true
  end

  function showText( bubble, message ) 
    local options = {
        text = " ",
        x = bubble.contentBounds.xMin + 15, 
        y = bubble.contentBounds.yMin + 10,
        fontSize = 12.5,
        width = bubble.width - 27,
        height = 0,
        align = "left" 
    }
    options.text = message[1]

    if ( bubble.alpha == 0 ) then
      transition.fadeIn( bubble, { time = 400 } )
    end

    listeners:add( bubble, "tap", showSubText )

    local newText = display.newText( options ) 
    newText.x = newText.x + newText.width/2
    newText.y = newText.y + newText.height/2

    bubble.message = message 
    bubble.text = newText
    bubble.shownText = 1
    bubble.options = options

    local time 
    if ( not bubble.blinkingDart ) then 
      time = 500

      bubble.blinkingDart = map:findObject( "blinkingDart" ) 
      bubble.blinkingDart.x = bubble.x + 33
      bubble.blinkingDart.y = bubble.y + 12

      bubble.blinkingDart.alpha = 1
      transition.blink( bubble.blinkingDart, { time = time } )
    end

    if ( ( messageBubble ) and ( messageBubble ~= bubble ) ) then
      listeners:remove( messageBubble, "tap", showSubText )
      messageBubble = bubble
    elseif ( not messageBubble ) then 
      messageBubble = bubble
    end
  end
-- -----------------------------------------------------------------------------------
-- Listeners
-- -----------------------------------------------------------------------------------
-- Trata dos tipos de colisão
local function onCollision( event )
  phase = event.phase
  local obj1 = event.object1
  local obj2 = event.object2
 
  if ( event.phase == "began" ) then
    if ( ( ( obj1.myName == "house" ) and ( obj2.myName == "character" ) ) or ( ( obj1.myName == "character" ) and ( obj2.myName == "house" ) ) ) then 
      transition.cancel()
      if ( obj1.point ) then character.stepping.point = obj1.point else character.stepping.point = obj2.point end 
      instructions:destroyInstructionsTable()
      gamePanel:stopAllListeners()
      timer.performWithDelay( 800, sceneTransition.gotoHouse )

    elseif ( ( ( obj1.myName == "school" ) and ( obj2.myName == "character" ) ) or ( ( obj1.myName == "character" ) and ( obj2.myName == "school" ) ) ) then 
      transition.cancel()
      if ( obj1.point ) then character.stepping.point = obj1.point else character.stepping.point = obj2.point end 
      instructions:destroyInstructionsTable()
      gamePanel:stopAllListeners()
      timer.performWithDelay( 800, sceneTransition.gotoSchool ) 
    -- Colisão entre o personagem e os sensores dos tiles do caminho
    elseif ( ( obj1.myName == "character" ) and ( obj2.isPath ) ) then 
      character.stepping.x = obj2.x 
      character.stepping.y = obj2.y 
      character.stepping.point = "point"
      path:showTile( obj2.myName )
    elseif ( ( obj2.myName == "character" ) and ( obj1.isPath ) ) then 
      character.stepping.x = obj1.x 
      character.stepping.y = obj1.y 
      character.stepping.point = "point"
      path:showTile( obj1.myName )
    
    elseif ( ( obj1.myName == "teacher" ) and ( obj2.myName == "character" ) ) then 
      teacher.cancelLoop = true
      instructionsTable.stop = true
      transition.cancel( character ) 

    elseif ( ( obj2.myName == "teacher" ) and ( obj1.myName == "character" ) ) then 
      teacher.cancelLoop = true 
      instructionsTable.stop = true
      transition.cancel( character ) 

    elseif ( ( ( obj1.myName == "collision" ) and ( obj2.myName == "rope" ) ) or ( ( obj1.myName == "rope" ) and ( obj2.myName == "collision" ) ) ) then 
      transition.cancel()
    end
  end
  return true 
end

-- -----------------------------------------------------------------------------------
-- Remoções para limpar a tela
-- -----------------------------------------------------------------------------------
local function destroyMap()
  camera:destroy()
  camera = nil 
  map:removeSelf()
  character.ropeJoint:removeSelf()
  character.rope:removeSelf()

  map = nil 
  character.ropeJoint = nil 
  character.rope = nil 
  character = nil 

  path:destroy()
end

local function destroyScene()
  listeners:remove( Runtime, "collision", onCollision )
  gamePanel:destroy()

  instructions:destroyInstructionsTable()

  destroyMap()
end

local function jumpingLoop( nextLevelCharacter, bubble, msg )
  local function closure()
    jumpingLoop( nextLevelCharacter, bubble, msg )
  end

  if ( nextLevelCharacter.cancelLoop == false ) then
    transition.to(  nextLevelCharacter, { y = nextLevelCharacter.y - 8, transition = easing.continuousLoop, onComplete = closure } )
  else 
    showText( bubble, msg )
  end
end

function setNextLevelCharacter()
  if ( ( gameFileData.house.isComplete == true ) and ( gameFileData.school.isComplete == false ) ) then 
      gamePanel:updateBikeMaxCount( 2 )
      teacher.alpha = 1
      physics.addBody( teacher, { isSensor = true, bodyType = "static" } )
      
      jumpingLoop( teacher, map:findObject( "teacherBubble" ), message.teacher )
  end
end

-- -----------------------------------------------------------------------------------
-- Cenas
-- -----------------------------------------------------------------------------------
-- create()
function scene:create( event )
  sceneGroup = self.view

  --persistence.setCurrentFileName("ana")

  map, character, gamePanel, gameState, path, instructions, instructionsTable, gameFileData = gameScene:set( "map" )
  map.x = map.x - 20
  map.y = map.y - 15

  teacher = map:findObject( "teacher" )

  --[[instructionsTable.direction = { "right", "down", "right" }
  instructionsTable.steps = { 2, 2, 2 }
  instructionsTable.last = 3]]

  --[[instructionsTable.direction = { "right", "down", "up", "down", "down", "right", "right" }
  instructionsTable.steps = { 2, 2, 2, 1, 1, 1, 1  }
  instructionsTable.last = 7]]

  sceneGroup:insert( map )
  sceneGroup:insert( gamePanel.tiled )
end

-- show()
function scene:show( event )
  local sceneGroup = self.view
  local phase = event.phase

  if ( phase == "will" ) then
    --setCamera()
    listeners:add( Runtime, "collision", onCollision )
    gamePanel:addDirectionListeners()

    setNextLevelCharacter()

  elseif ( phase == "did" ) then
    gamePanel:addButtonsListeners()
    gamePanel:addInstructionPanelListeners()


  
    --instructionsTable.direction = {"right","down","right","down","right","right","up","left","right","down","left","down","left","down","left","up","right","up","left","up","right"}
    --instructionsTable.steps = {5,6,6,2,3,6,6,5,5,6,2,9,7,3,13,6,3,8,4,6,3}
    --instructionsTable.last = 21

    --instructionsTable.direction = {"right","down","right","down","left","down","right","up","right","down","left","down","left","up","left","up","left","up","left","up","right"}
    --instructionsTable.steps = {2,2,2,2,2,2,6,3,3,6,3,3,3,1,3,2,3,2,1,7,4}
    --instructionsTable.last = 21
    
    

  end
end

-- hide()
function scene:hide( event )
  local sceneGroup = self.view
  local phase = event.phase
  if ( phase == "will" ) then
    gameFileData.character = character
    gameState:save( gameFileData )
    destroyScene()
    listeners:destroy()
  elseif ( phase == "did" ) then
    composer.removeScene( "map" )
  end
end

-- destroy()
function scene:destroy( event )
 
  local sceneGroup = self.view
  --gamePanel:removegotoMenuButton()
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