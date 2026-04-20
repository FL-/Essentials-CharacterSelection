#===============================================================================
# * Character Selection - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It's a character selection screen
# suggested for player selection or partner selection.
#
#== HOW TO USE =================================================================
#
# Call 'CharacterSelection.start(overworld,battle)' passing two arrays with the
# same size as arguments: 
#
# - The first include overworld graphics names (from "Graphics/Characters").
# - The second include battler/front graphics names (from "Graphics/Trainers" 
# or, in older Essentials, "Graphics/Characters").
#
# The return is the player selected index, starting at 0. 
#
#== EXAMPLES ===================================================================
#
# A basic example that initialize the player:
#
#  overworld = [
#   "trainer_POKEMONTRAINER_Red",
#   "trainer_POKEMONTRAINER_Leaf"]
#  battle = ["POKEMONTRAINER_Red",
#   "POKEMONTRAINER_Leaf"]
#  r=CharacterSelection.start(
#   overworld,battle) 
#  pbChangePlayer(r+1)
#
# Example with 4 characters. This example won't change your character, just 
# store the index result at game variable 70. Since this example uses a wider 
# line, you should run extended.exe before or your game will crash.
#
#  overworld = [
#    "trainer_POKEMONTRAINER_Red", "trainer_POKEMONTRAINER_Leaf",
#    "trainer_POKEMONTRAINER_Brendan","trainer_POKEMONTRAINER_May"
#  ]
#  battle = [
#    "POKEMONTRAINER_Red","POKEMONTRAINER_Leaf",
#    "POKEMONTRAINER_Brendan","POKEMONTRAINER_May"
#  ]
#  $game_variables[70] = CharacterSelection.start(overworld,battle) 
#
#===============================================================================

module CharacterSelection
  class Scene
    BACKGROUND_SPEED = 120
    ANIMATION_FRAME_INTERVAL = 4 # Increase for slower animation.
    TURN_DURATION = 3.2
    
    def start(overworld,battle)
      @overworld = overworld
      @battle = battle
      @sprites={}
      @sync_sprite_array = [] # Sprites that need sync
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=99999
      @sprites["bg"]=BackgroundPlane.new(BACKGROUND_SPEED,TURN_DURATION,@viewport)
      @sprites["bg"].setBitmap("Graphics/UI/character_selection_tile")
      @sync_sprite_array.push(@sprites["bg"])
      @sprites["arrow"]=IconSprite.new(@viewport)
      @sprites["arrow"].setBitmap(Bridge.sel_arrow_path)
      @sprites["battlerbox"]=Window_AdvancedTextPokemon.new("")
      @sprites["battlerbox"].viewport=@viewport
      pbBottomLeftLines(@sprites["battlerbox"],5)
      @sprites["battlerbox"].width=256
      @sprites["battlerbox"].x=Graphics.width-@sprites["battlerbox"].width
      @sprites["battlerbox"].z=0
      @sprites["battler"]=IconSprite.new(384,284,@viewport)
      create_character_sprites
      update_cursor
      @sprites["messagebox"]=Window_AdvancedTextPokemon.new(_INTL("Choose your character."))
      @sprites["messagebox"].viewport=@viewport
      pbBottomLeftLines(@sprites["messagebox"],5)
      @sprites["messagebox"].width=256
      pbFadeInAndShow(@sprites) { update }
    end

    def create_character_sprites
      lines = 2
      totalWidth = 512
      totalHeight = 232
      marginX = totalWidth/((@overworld.size/2.0).ceil+1)
      marginY = 72
      for i in 0...@overworld.size
        @sprites["icon#{i}"]=AnimatedChar.new(
          "Graphics/Characters/"+@overworld[i], 4, 
          Bridge.to_AnimatedSprite_frameskip([ANIMATION_FRAME_INTERVAL-1,0].max), TURN_DURATION, @viewport
        )
        @sprites["icon#{i}"].x = marginX*((i/2).floor+1)
        @sprites["icon#{i}"].y = marginY+(totalHeight - marginY*2)*(i%lines)
        @sprites["icon#{i}"].start
        @sync_sprite_array.push(@sprites["icon#{i}"])
      end
    end
    
    def update_cursor(index=nil)
      @index=0
      if index
        pbPlayCursorSE
        @index=index
      end
      @sprites["arrow"].x=@sprites["icon#{@index}"].x-32
      @sprites["arrow"].y=@sprites["icon#{@index}"].y-32
      @sprites["battler"].setBitmap(Bridge.trainer_bitmap_path + @battle[@index])
      @sprites["battler"].ox=@sprites["battler"].bitmap.width/2
      @sprites["battler"].oy=@sprites["battler"].bitmap.height/2
    end
    
    def main_loop
      loop do
        Graphics.update
        Input.update
        self.update
        if Input.trigger?(Input::C)
          pbPlayDecisionSE
          if display_confirm(_INTL("Are you sure?"))
            pbPlayDecisionSE
            return @index
          else 
            pbPlayCancelSE
          end
        end
        lines=2
        if Input.repeat?(Input::LEFT)
          update_cursor(@index - lines >= 0 ? @index-lines : @overworld.size - lines + (@index%lines))
        end
        if Input.repeat?(Input::RIGHT)
          update_cursor((@index + lines <= @overworld.size - 1) ? @index + lines : @index % lines)
        end
        if Input.repeat?(Input::UP)
          update_cursor(@index != 0 ? @index - 1 : @overworld.size - 1)
        end
        if Input.repeat?(Input::DOWN)
          update_cursor(@index != @overworld.size - 1 ? @index + 1 : 0)  
        end
      end 
    end
    
    def update
      update_deltas(@sync_sprite_array, Bridge.delta)
      pbUpdateSpriteHash(@sprites)
    end

    # Update sprites with delta to make sure they are synchronized.
    def update_deltas(sprite_array, delta)
      for sprite in sprite_array
        sprite.delta = delta
      end
    end
    
    def display_confirm(text)
      ret=-1
      oldtext=@sprites["messagebox"].text
      @sprites["messagebox"].text=text
      using(cmdwindow=Window_CommandPokemon.new([_INTL("Yes"),_INTL("No")])){
        cmdwindow.z=@viewport.z+1
        cmdwindow.visible=false
        pbBottomRight(cmdwindow)
        cmdwindow.y-=@sprites["messagebox"].height
        loop do
          Graphics.update
          Input.update
          cmdwindow.visible=true if !@sprites["messagebox"].busy?
          cmdwindow.update
          self.update
          if Input.trigger?(Input::B) && !@sprites["messagebox"].busy?
            ret=false
          end
          if Input.trigger?(Input::C) && @sprites["messagebox"].resume && !@sprites["messagebox"].busy?
            ret = cmdwindow.index==0
            break
          end
        end
      }
      @sprites["messagebox"].text=oldtext
      return ret
    end
    
    def finish
      pbFadeOutAndHide(@sprites) { update }
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
    end
  end

  class BackgroundPlane < AnimatedPlane
    attr_writer :delta

    LIMIT=16
    
    def initialize(speed, turn_time, viewport)
      @float_ox = 0
      @float_oy = 0
      super(viewport)
      @speed = speed
      @turn_time = turn_time
      @turn_time_remaining = @turn_time
      @delta = 0
      @direction=0 if !@direction
    end
    
    def update
      super
      @turn_time_remaining -= @delta
      turn if @turn_time_remaining <= 0
      update_movement(@speed*@delta)
    end

    def turn
      @turn_time_remaining += @turn_time
      @direction+=1
      @direction=0 if @direction==4
    end

    def update_movement(quantity)
      case @direction
      when 0 # down
        @float_oy = wrap_value(@float_oy + quantity, LIMIT)
      when 1 # left
        @float_ox = wrap_value(@float_ox - quantity,-LIMIT)
      when 2 # up
        @float_oy = wrap_value(@float_oy - quantity,-LIMIT)
      when 3 # right
        @float_ox = wrap_value(@float_ox + quantity, LIMIT)
      end
      self.ox = @float_ox.round
      self.oy = @float_oy.round
    end

    def wrap_value(value, limit)
      value = value-limit if value>=limit
      value = value+limit if value<=-limit
      return value
    end
  end

  class AnimatedChar < AnimatedSprite
    attr_writer :delta
    
    def initialize(*args)
      @direction=0
      @delta=0
      @turn_time=args[3]
      @turn_time_remaining = @turn_time
      super([args[0],args[1],args[2],args[4]])
      @frameheight=@animbitmap.height/4
      if @animbitmap.width % framecount!=0
        raise _INTL("Bitmap's width ({1}) is not a multiple of frame count ({2}) [Bitmap={3}]",@animbitmap.width,@framewidth,@animname)
      end
      @playing=false
      self.src_rect.height=@frameheight
      self.ox=@framewidth/2
      self.oy=@frameheight
    end
  
    def frame=(value)
      @frame=value
      self.src_rect.x = @frame % @framesperrow * @framewidth
    end
  
    def update
      super
      return if !@playing
      @turn_time_remaining -= @delta
      turn if @turn_time_remaining <= 0
    end

    def turn
      @turn_time_remaining += @turn_time 
      @direction += 1
      @direction = 0 if @direction==4
      if @direction==2
        dir=3
      elsif @direction==3
        dir=2
      else
        dir=@direction
      end  
      self.src_rect.y=@frameheight*dir
    end
  end

  class Screen
    def initialize(scene)
      @scene=scene
    end
    
    def start(overworld,battle)
      @scene.start(overworld,battle)
      ret = @scene.main_loop
      @scene.finish
      return ret
    end
  end

  module Bridge
    module_function

    def major_version
      ret = 0
      if defined?(Essentials)
        ret = Essentials::VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALS_VERSION)
        ret = ESSENTIALS_VERSION.split(".")[0].to_i
      elsif defined?(ESSENTIALSVERSION)
        ret = ESSENTIALSVERSION.split(".")[0].to_i
      end
      return ret
    end

    MAJOR_VERSION = major_version

    def delta
      return 0.025 if MAJOR_VERSION < 21
      return Graphics.delta
    end

    def to_AnimatedSprite_frameskip(value)
      return value*2 if MAJOR_VERSION < 18
      return value
    end

    def sel_arrow_path
      return "Graphics/Pictures/selarrow" if MAJOR_VERSION < 21
      return "Graphics/UI/sel_arrow"
    end

    def trainer_bitmap_path
      return "Graphics/Characters/" if MAJOR_VERSION < 18
      return "Graphics/Trainers/"
    end
  end

  def self.start(overworld,battle)
    ret = nil
    pbFadeOutIn(99999) {
      scene=Scene.new
      screen=Screen.new(scene)
      ret=screen.start(overworld,battle)
    }
    return ret
  end
end