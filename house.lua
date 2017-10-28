local composer = require( "composer" )

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

local fsm = require "com.fsm.src.fsm"

physics.start()
physics.setGravity( 0, 0 )

-- -----------------------------------------------------------------------------------
-- Declaração das variáveis
-- -----------------------------------------------------------------------------------
local house 

local character

local rope 

local ropeJoint

local tilesSize = 32

local stepDuration = 50

local house

local puzzle = { bigPieces = { }, littlePieces = { count }, puzzleSensors = { } }

local miniGameData

local collectedPieces = { count = 0 }

local controlsTutorialFSM

local messageBubble

local animation = {}

local message = {}

-- -----------------------------------------------------------------------------------
-- Remoções para limpar a tela
-- -----------------------------------------------------------------------------------
local function destroyScene()
  Runtime:removeEventListener( "collision", onCollision )
  gamePanel:destroy()

  instructions:destroyInstructionsTable()

  house:removeSelf()
  house = nil 

  if ( ( messageBubble ) and ( messageBubble.text ) ) then
    messageBubble.text:removeSelf()
    messageBubble.text = nil 
  end

  controlsTutorialFSM = nil 
end

local function setPuzzle()
  local bigPiecesLayer = house:findLayer("big puzzle") 
  local littlePiecesLayer = house:findLayer("little puzzle") 
  local puzzleSensorsLayer = house:findLayer("puzzle sensors")
  
  for i = 1, bigPiecesLayer.numChildren do
    puzzle.bigPieces[ bigPiecesLayer[i].myName ] = bigPiecesLayer[i]
    puzzle.puzzleSensors[ puzzleSensorsLayer[i].puzzleNumber ] = puzzleSensorsLayer[i]
    physics.addBody( puzzleSensorsLayer[i], { bodyType = "static", isSensor = true } )  
    littlePiecesLayer[i].alpha = 1
    puzzle.littlePieces[ littlePiecesLayer[i].myName ] = littlePiecesLayer[i]
  end
  
  puzzle.littlePieces.count = bigPiecesLayer.numChildren
end

local function executeControlsTutorial( event, alternativeEvent )
  if ( controlsTutorialFSM ) then 
    if ( ( messageBubble ) and ( messageBubble.text ) ) then
      messageBubble.text:removeSelf()
      messageBubble.text = nil
    end

    if ( alternativeEvent ) then
      if ( alternativeEvent == "showMessage" ) then
        controlsTutorialFSM.showMessage()
      elseif ( alternativeEvent == "transitionEvent" ) then
        controlsTutorialFSM.transitionEvent()
        executeControlsTutorial()
      end

    else
      if ( controlsTutorialFSM.nextEvent == "showAnimation" ) then 
        controlsTutorialFSM.showAnimation()
        timer.performWithDelay( animation[controlsTutorialFSM.current](), executeControlsTutorial )

      elseif ( controlsTutorialFSM.nextEvent == "showMessage" ) then 
        controlsTutorialFSM.showMessage()

      elseif ( controlsTutorialFSM.nextEvent == "showTempMessage" ) then 
        controlsTutorialFSM.showTempMessage()
      
      elseif ( controlsTutorialFSM.nextEvent == "showMessageAndAnimation" ) then 
        controlsTutorialFSM.showMessageAndAnimation()
        local _, animationName = controlsTutorialFSM.current:match( "([^,]+)_([^,]+)" )
        local from, wait, n = controlsTutorialFSM.from:match( "([^,]+)_([^,]+)_([^,]+)" )
        
        if ( ( from == "transitionState" ) and ( wait ) ) then 
          timer.performWithDelay( wait, animation[animationName] )
        else
          animation[animationName]()
        end
      
      elseif ( controlsTutorialFSM.nextEvent == "transitionEvent" ) then 
        controlsTutorialFSM.transitionEvent()
        executeControlsTutorial()

      elseif ( controlsTutorialFSM.nextEvent == "saveEvent" ) then
        controlsTutorialFSM.saveEvent()
        miniGameData.controlsTutorial = "complete"
        --gameState:save( miniGameData )
        executeControlsTutorial()

      elseif ( controlsTutorialFSM.nextEvent == "showFeedback" ) then
        controlsTutorialFSM.showFeedback()
        executeControlsTutorial()

      elseif ( controlsTutorialFSM.nextEvent == "nextTutorial" ) then
        controlsTutorialFSM.nextTutorial()
      end
    end
  end
end

local function showSubText( event )
  messageBubble = event.target

  if ( messageBubble.message[messageBubble.shownText] ) then 
    messageBubble.text:removeSelf()

    local remainingPieces = puzzle.littlePieces.count - collectedPieces.count

    if ( ( controlsTutorialFSM.current == "msg6" ) and ( messageBubble.message[messageBubble.shownText] == "Mas ainda falta" ) ) then 
      if ( remainingPieces > 1 ) then
        messageBubble.options.text = messageBubble.message[messageBubble.shownText] .. "m " .. remainingPieces .. " peças."
      else
        messageBubble.options.text = messageBubble.message[messageBubble.shownText] .. " " .. remainingPieces .. " peça."
      end
    else
      messageBubble.options.text = messageBubble.message[messageBubble.shownText]
    end

    local newText = display.newText( messageBubble.options ) 
    newText.x = newText.x + newText.width/2
    newText.y = newText.y + newText.height/2

    messageBubble.text = newText
    messageBubble.shownText = messageBubble.shownText + 1

  else
    if ( controlsTutorialFSM.event == "showMessage" ) then
      transition.fadeOut( messageBubble.text, { time = 400 } )
      transition.fadeOut( messageBubble, { time = 400, onComplete = executeControlsTutorial } )
      messageBubble.text:removeSelf()
      messageBubble.text = nil
      messageBubble:removeEventListener( "tap", showSubText )
    else
      transition.fadeOut( messageBubble.text, { time = 400 } )
      transition.fadeOut( messageBubble, { time = 400 } )
      messageBubble.text:removeSelf()
      messageBubble.text = nil
      messageBubble:removeEventListener( "tap", showSubText )
    end
  end
end

local function showText( bubble, message )
  messageBubble = bubble 
  local options = {
      text = " ",
      x = messageBubble.contentBounds.xMin + 15, 
      y = messageBubble.contentBounds.yMin + 10,
      fontSize = 13,
      width = messageBubble.width - 27,
      height = 0,
      align = "left" 
  }
  options.text = message[1]

  local newText = display.newText( options ) 
  newText.x = newText.x + newText.width/2
  newText.y = newText.y + newText.height/2

  if ( messageBubble.alpha == 0 ) then
    transition.fadeIn( messageBubble, { time = 400 } )
    messageBubble:addEventListener( "tap", showSubText )
  end 

  messageBubble.message = message 
  messageBubble.text = newText
  messageBubble.shownText = 1
  messageBubble.options = options

end

local function momAnimation( )
  local time = 5000
  transition.to( house:findObject("mom"), { time = time, x = character.x, y = character.y - tilesSize } )

  return time + 500
end

local function handDirectionAnimation( time, hand, initialX, initialY, x, y, state )
  if ( state ~= controlsTutorialFSM.current ) then
    return
  else 
    hand.x = initialX
    hand.y = initialY
    transition.to( hand, { time = time, x = x, y = y } )
    local closure = function ( ) return handDirectionAnimation( time, hand, initialX, initialY, x, y, state ) end
    timer.performWithDelay(time + 400, closure)
  end
end

local function handDirectionAnimation1( )
  local hand = gamePanel.hand
  local box = gamePanel.firstBox
  local time = 1500

  hand.x = hand.originalX 
  hand.y = hand.originalY
  hand.alpha = 1
   

  handDirectionAnimation( time, hand, hand.originalX, hand.originalY, hand.x, box.y - 5, controlsTutorialFSM.current )
  
  gamePanel:addRightDirectionListener( executeControlsTutorial )
end

local function handDirectionAnimation2( )
  local hand = gamePanel.hand
  local box = gamePanel.secondBox
  local time = 1500

  hand.x = hand.originalX 
  hand.y = hand.originalY
  hand.alpha = 1
   

  handDirectionAnimation( time, hand, hand.originalX, hand.originalY, hand.x, box.y - 5, controlsTutorialFSM.current )
  
  gamePanel:addRightDirectionListener( executeControlsTutorial )
end

local function handWalkAnimation( )
  local hand = gamePanel.hand
  local executeButton = gamePanel.executeButton
  local time = 1500

  hand.x = executeButton.x 
  hand.y = executeButton.y
  hand.alpha = 1
   

  handDirectionAnimation( time, hand, executeButton.contentBounds.xMin + 2, executeButton.y, executeButton.contentBounds.xMin + 10, executeButton.y - 5, controlsTutorialFSM.current )
    

  gamePanel:addExecuteButtonListener( executeControlsTutorial )
end


local function gamePanelAnimation( )
  gamePanel:showDirectionButtons( true )
end

animation["momAnimation"] = momAnimation
animation["handDirectionAnimation1"] = handDirectionAnimation1
animation["handDirectionAnimation2"] = handDirectionAnimation2
animation["handWalkAnimation"] = handWalkAnimation
animation["gamePanelAnimation"] = gamePanelAnimation
 

message["msg1"] = { "Tenho um presente para você.",
                  "Encontre todas as peças de",
                  "quebra-cabeça que escondi",
                  "pela casa para descobrir",
                  "o que é." }

message["msg2"] = { "Arraste a seta da direita para", 
                    "o retângulo laranja para andar",
                    "um quadradinho" }

message["msg3"] = { "Muito bem! Arraste mais uma",
                    "seta para completar o caminho." }

message["msg4"] = { "Agora aper-te no botão \"andar\"." }
message["msg5"] = { "Parabéns! Agora tente pegar as",
                    "outras peças usando", 
                    "também outras setas." }
message["msg6"] = { "Muito bem! Você está perto de",
                    "descobrir qual é o presente.",
                    "Mas ainda falta" }
message["msg7"] = { "Parabéns! Você ga-nhou uma",
                    "bicicleta." }

local function controlsTutorial( )
  controlsTutorialFSM = fsm.create({
    initial = "start",
    events = {
      {name = "showAnimation",  from = "start",  to = "momAnimation", nextEvent = "showMessage" },
      {name = "showMessage",  from = "momAnimation",  to = "msg1", nextEvent = "showMessageAndAnimation" },
      {name = "showMessageAndAnimation",  from = "msg1",  to = "msg2_handDirectionAnimation1", nextEvent = "transitionEvent" },
      {name = "transitionEvent",  from = "msg2_handDirectionAnimation1",  to = "transitionState_100_1", nextEvent = "showMessageAndAnimation" },
      
      {name = "showMessageAndAnimation",  from = "transitionState_100_1",  to = "msg3_handDirectionAnimation2", nextEvent = "transitionEvent" },
      {name = "transitionEvent",  from = "msg3_handDirectionAnimation2",  to = "transitionState_100_2", nextEvent = "showMessageAndAnimation" },
      
      {name = "showMessageAndAnimation",  from = "transitionState_100_2",  to = "msg4_handWalkAnimation", nextEvent = "transitionEvent" },
      {name = "transitionEvent",  from = "msg4_handWalkAnimation",  to = "transitionState_100_3", nextEvent = "showMessageAndAnimation" },
      {name = "showMessageAndAnimation",  from = "transitionState_100_3",  to = "msg5_gamePanelAnimation", nextEvent = "showTempMessage" },

      {name = "showTempMessage",  from = "msg5_gamePanelAnimation",  to = "msg6", nextEvent = "showTempMessage" },

      {name = "showTempMessage",  from = "msg6",  to = "msg6", nextEvent = "showTempMessage" },
      {name = "transitionEvent",  from = "msg6",  to = "transitionState4", nextEvent = "saveEvent" },
      {name = "saveEvent",  from = "transitionState4",  to = "save", nextEvent = "showMessage" },
      {name = "showMessage",  from = "save",  to = "msg7", nextEvent = "showFeedback" },
      {name = "showFeedback",  from = "msg7",  to = "feedback", nextEvent = "nextTutorial" },
      {name = "nextTutorial",  from = "feedback",  to = "tutorial" },
    },
    callbacks = {
      on_showMessage = function( self, event, from, to ) 
        showText( house:findObject("message"), message[self.current] )
      end,
      on_showTempMessage = function( self, event, from, to ) 
          if ( self.current ~= "msg6" ) then 
            showText( house:findObject("message"), message[self.current] )
          else
            local remainingPieces = puzzle.littlePieces.count - (collectedPieces.count + 1)

            showText( house:findObject("message"), message[self.current] )
          end
      end,
      on_showMessageAndAnimation = function( self, event, from, to )
        local msg, animationName = controlsTutorialFSM.current:match( "([^,]+)_([^,]+)" ) 
        showText( house:findObject("message"), message[msg] )

        return animationName
      end,
      on_nextTutorial = function( self, event, from, to ) 
         
      end
    }
  })

  
  controlsTutorialFSM.showAnimation()
  timer.performWithDelay( animation[controlsTutorialFSM.current](), executeControlsTutorial )
  

end


-- -----------------------------------------------------------------------------------
-- Listeners
-- -----------------------------------------------------------------------------------
-- Trata dos tipos de colisão da casa
local function onCollision( event )
  phase = event.phase
  local obj1 = event.object1
  local obj2 = event.object2

  if ( event.phase == "began" ) then
    if ( ( obj1.myName == "puzzle" ) and ( obj2.myName == "character" ) ) then
      if ( collectedPieces[obj1.puzzleNumber] == nil ) then 
        puzzle.bigPieces[obj1.puzzleNumber].alpha = 1
        puzzle.littlePieces[ obj1.puzzleNumber ].alpha = 0
        collectedPieces[ obj1.puzzleNumber ] = puzzle.littlePieces[ obj1.puzzleNumber ]
        local remainingPieces = puzzle.littlePieces.count - (collectedPieces.count + 1)

        if ( ( collectedPieces.count ~= 0 ) and ( remainingPieces > 0 ) ) then
          executeControlsTutorial()
        elseif ( remainingPieces <= 0 ) then 
          executeControlsTutorial( _, "transitionEvent" )
        end
        collectedPieces.count = collectedPieces.count + 1

        print( "collectedPieces: " .. collectedPieces.count .. "; remain: " .. remainingPieces )
      end 
    elseif ( ( obj1.myName == "character" ) and ( obj2.myName == "puzzle" ) ) then 
      if ( collectedPieces[obj2.puzzleNumber] == nil ) then
        puzzle.bigPieces[obj2.puzzleNumber].alpha = 1
        puzzle.littlePieces[ obj2.puzzleNumber ]. alpha = 0
        collectedPieces[ obj2.puzzleNumber ] = puzzle.littlePieces[ obj2.puzzleNumber ]
        local remainingPieces = puzzle.littlePieces.count - (collectedPieces.count + 1)


        if ( ( collectedPieces.count ~= 0 ) and ( remainingPieces > 0 ) ) then
          executeControlsTutorial()
        elseif ( remainingPieces <= 0 ) then 
          executeControlsTutorial( _, "transitionEvent" )
        end
        collectedPieces.count = collectedPieces.count + 1
      end

    -- Volta para o mapa quando o personagem chega na saída/entrada da casa
    elseif ( ( ( obj1.myName == "exit" ) and ( obj2.myName == "character" ) ) or ( ( obj1.myName == "character" ) and ( obj2.myName == "exit" ) ) ) then 
      if ( miniGameData.isComplete == true ) then
        transition.cancel()
        instructions:destroyInstructionsTable()
        gamePanel:stopAllListeners()
        timer.performWithDelay( 800, sceneTransition.gotoMap )
      end
    elseif ( ( ( obj1.myName == "entrace" ) and ( obj2.myName == "character" ) ) or ( ( obj1.myName == "character" ) and ( obj2.myName == "entrance" ) ) ) then 
      if ( miniGameData.isComplete == true ) then
        transition.cancel()
        instructions:destroyInstructionsTable()
        gamePanel:stopAllListeners()
        timer.performWithDelay( 800, sceneTransition.gotoMap )
      end
    -- Colisão entre o personagem e os sensores dos tiles do caminho
    elseif ( ( obj1.myName == "character" ) and ( obj2.myName ~= "collision" ) ) then 
      character.steppingX = obj2.x 
      character.steppingY = obj2.y 
      path:showTile( obj2.myName )

    elseif ( ( obj2.myName == "character" ) and ( obj1.myName ~= "collision" ) ) then 
      character.steppingX = obj1.x 
      character.steppingY = obj1.y 
      path:showTile( obj1.myName )

    -- Colisão com os demais objetos e o personagem (rope nesse caso)
    elseif ( ( ( obj1.myName == "collision" ) and ( obj2.myName == "rope" ) ) or ( ( obj1.myName == "rope" ) and ( obj2.myName == "collision" ) ) ) then 
      transition.cancel()
    end
  end 
  return true 
end
-- -----------------------------------------------------------------------------------
-- Cenas
-- -----------------------------------------------------------------------------------
-- create()
function scene:create( event )
	local sceneGroup = self.view

  --print( display.actualContentWidth )
  --print( display.actualContentHeight )

  --persistence.setCurrentFileName( "ana" )

	house, character, rope, ropeJoint, gamePanel, gameState, path, instructions, instructionsTable, miniGameData = gameScene:set( "house", onCollision )

  if ( character.flipped == true ) then
    character.xScale = -1
  end

  

  sceneGroup:insert( house )
  sceneGroup:insert( gamePanel.tiled )

  if ( miniGameData.controlsTutorial == "incomplete" ) then 
    setPuzzle()
  end
end

-- show()
function scene:show( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
    if ( miniGameData.controlsTutorial == "complete" ) then
		  gamePanel:addDirectionListeners()
    end

	elseif ( phase == "did" ) then
    if ( miniGameData.controlsTutorial == "complete" ) then
      gamePanel:showDirectionButtons( false )
		  gamePanel:addButtonsListeners()
      gamePanel:addInstructionPanelListeners()

    else
      if ( miniGameData.controlsTutorial == "incomplete" ) then
        controlsTutorial()
      end
      --gamePanel:addGoBackButtonListener()
    end
	end
end


-- hide()
function scene:hide( event )

	local sceneGroup = self.view
	local phase = event.phase

	if ( phase == "will" ) then
		physics.stop( )
		gameState:save( miniGameData )
		destroyScene()
	elseif ( phase == "did" ) then
    composer.removeScene( "house" )
	end
end


-- destroy()
function scene:destroy( event )

	local sceneGroup = self.view
	--gamePanel:removeGoBackButton()
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
