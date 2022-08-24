#===============================================================================
# * Character Selection - by FL (Credits will be apreciated)
#===============================================================================
#
# This script is for Pokémon Essentials. It's a character selection screen
# suggested for player selection or partner selection.
#
#===============================================================================
#
# To this script works, put it above main and put a 32x32 background at 
# "Graphics/Pictures/characterselectiontile" (may works with other sizes).
#
# To call this script, use 'pbCharacterSelection(overworld,battle)' passing two
# arrays as arguments: the first must have the overworld graphics names and the
# second must have the battle graphics, both using "Graphics/Pictures/" as 
# directory. Both arrays must have the same since that can't be an odd number.
# The return is the player selected index, starting at 0. 
#
# An example that initialize the player:
#
# overworld = ["trchar000","trchar001","trchar002","trchar003"]
# battle = ["trainer000","trainer001","trainer002","trainer003"]
# result = pbCharacterSelection(overworld,battle) 
# pbChangePlayer(result)
#
#===============================================================================

class CharacterSelectionScene
  SPEED=2 # Can be 1, 2, 4 or 8.
  TURNTIME=128 # In frames
  
  def pbStartScene(overworld,battle)
    @overworld = overworld
    @battle = battle
    @sprites={}
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=99999
    @sprites["bg"]=CharacterSelectionPlane.new(SPEED,TURNTIME,@viewport)
    @sprites["bg"].setBitmap("Graphics/Pictures/characterselectiontile")
    @sprites["arrow"]=IconSprite.new(@viewport)
    @sprites["arrow"].setBitmap("Graphics/Pictures/selarrow")
    @sprites["battlerbox"]=Window_AdvancedTextPokemon.new("")
    @sprites["battlerbox"].viewport=@viewport
    pbBottomLeftLines(@sprites["battlerbox"],5)
    @sprites["battlerbox"].width=256
    @sprites["battlerbox"].x=Graphics.width-@sprites["battlerbox"].width
    @sprites["battlerbox"].z=0
    @sprites["battler"]=IconSprite.new(384,284,@viewport)
    # Numbers for coordinates calculation
    lines = 2
    marginX = 64
    marginY = 72
    lastPointX = 512
    lastPointY = 232
    diferenceX = lastPointX - marginX*2
    diferenceY = lastPointY - marginY*2
    for i in 0...@overworld.size
      @sprites["icon#{i}"]=AnimatedChar.new(
          "Graphics/Characters/"+@overworld[i],4,16/SPEED,TURNTIME,@viewport)
      @sprites["icon#{i}"].x= @overworld.size<=2 ? marginX + (diferenceX / 2) :
          marginX+(diferenceX*(i/2))/((@overworld.size-1)/2)
      @sprites["icon#{i}"].y=marginY+diferenceY*(i%lines)
      @sprites["icon#{i}"].start
    end
    updateCursor
    @sprites["messagebox"]=Window_AdvancedTextPokemon.new(
        _INTL("Choose your character."))
    @sprites["messagebox"].viewport=@viewport
    pbBottomLeftLines(@sprites["messagebox"],5)
    @sprites["messagebox"].width=256
    pbFadeInAndShow(@sprites) { update }
  end
  
  def updateCursor(index=nil)
    @index=0
    if index
      pbSEPlay("Choose",80)
      @index=index
    end
    @sprites["arrow"].x=@sprites["icon#{@index}"].x-32
    @sprites["arrow"].y=@sprites["icon#{@index}"].y-32
    @sprites["battler"].setBitmap("Graphics/Characters/"+@battle[@index])
    @sprites["battler"].ox=@sprites["battler"].bitmap.width/2
    @sprites["battler"].oy=@sprites["battler"].bitmap.height/2
  end  
  
  def pbMidScene
   loop do
    Graphics.update
    Input.update
    self.update
    if Input.trigger?(Input::C)
      pbSEPlay("Choose",80)
      if pbDisplayConfirm(_INTL("Are you sure?"))
        pbSEPlay("Choose",80)
        return @index
      end
      pbSEPlay("Choose",80)
    end
    lines=2
    if Input.repeat?(Input::LEFT)
      updateCursor((@index-lines)>=0 ? 
          @index-lines : @overworld.size-lines+(@index%lines))
    end
    if Input.repeat?(Input::RIGHT)
      updateCursor((@index+lines)<=(@overworld.size-1) ? 
          @index+lines : @index%lines)
    end
    if Input.repeat?(Input::UP)
      updateCursor(@index!=0 ? @index-1 : @overworld.size-1)
    end
    if Input.repeat?(Input::DOWN)
      updateCursor(@index!=@overworld.size-1 ? @index+1 : 0)  
    end
   end 
  end
  
  def update
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbDisplayConfirm(text)
   ret=-1
   oldtext=@sprites["messagebox"].text
   @sprites["messagebox"].text=text
   using(cmdwindow=Window_CommandPokemon.new([_INTL("YES"),_INTL("NO")])){
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
       if (Input.trigger?(Input::C) && 
           @sprites["messagebox"].resume && !@sprites["messagebox"].busy?)
         ret=(cmdwindow.index==0)
         break
       end
     end
   }
   @sprites["messagebox"].text=oldtext
   return ret
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { update }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  class CharacterSelectionPlane < AnimatedPlane
    LIMIT=16
    
    def initialize(speed, turnTime, viewport)
      super(viewport)
      @speed = speed
      @turnTime = turnTime
    end  
    
    def update
      super
      @frame=0 if !@frame
      @frame+=1
      @direction=0 if !@direction
      if @frame==@turnTime
        @frame=0
        @direction+=1
        @direction=0 if @direction==4
      end
      case @direction
      when 0 #down
        self.oy+=@speed
      when 1 #left
        self.ox-=@speed
      when 2 #up
        self.oy-=@speed
      when 3 #right
        self.ox+=@speed
      end
      self.ox=0 if self.ox==-LIMIT || self.ox==LIMIT 
      self.oy=0 if self.oy==-LIMIT || self.oy==LIMIT 
    end
  end

  class AnimatedChar < AnimatedSprite
    def initialize(*args)
      viewport = args[4]
      @sprite=Sprite.new(viewport)
      @animname=pbBitmapName(args[0])
      @framecount=args[1]
      @frameskip=[1,args[2]].max
      @turnTime=args[3]
      @realframes=0
      @realframeschar=0
      @direction=0
      begin
        @animbitmap=AnimatedBitmap.new(animname).deanimate
      rescue
        @animbitmap=Bitmap.new(framecount*4,32)
      end
      if @animbitmap.width%framecount!=0
        raise _INTL("Bitmap's width ({1}) is not a multiple of frame count ({2}) [Bitmap={3}]",@animbitmap.width,framewidth,animname)
      end
      @framewidth=@animbitmap.width/@framecount
      @frameheight=@animbitmap.height/4
      @framesperrow=framecount
      @playing=false
      self.bitmap=@animbitmap
      self.src_rect.width=@framewidth
      self.src_rect.height=@frameheight
      self.ox=@framewidth/2
      self.oy=@frameheight
      self.frame=0
    end
  
    def frame=(value)
      @frame=value
      @realframes=0
      self.src_rect.x=@frame%@framesperrow*@framewidth
    end
  
    def update
      super
      if @playing
        @realframeschar+=1
        if @realframeschar==@turnTime
          @realframeschar=0 
          @direction+=1
          @direction= 0 if @direction==4
          #Spin
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
    end
  end  
end

class CharacterSelectionScreen
  def initialize(scene)
    @scene=scene
  end
  
  def pbStartScreen(overworld,battle)
    @scene.pbStartScene(overworld,battle)
    ret = @scene.pbMidScene
    @scene.pbEndScene
    return ret
  end
end

def pbCharacterSelection(overworld,battle)
  ret = nil
  pbFadeOutIn(99999) {
    scene=CharacterSelectionScene.new
    screen=CharacterSelectionScreen.new(scene)
    ret=screen.pbStartScreen(overworld,battle)
  }
  return ret
end