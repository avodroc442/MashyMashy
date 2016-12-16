  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring (horizontal scrolling)

;MITCH
;  .include "TitleScreen.asm"

; -----------------------------------
; Standard NES registers

PPU_CTRL_REG1         = $2000
PPU_CTRL_REG2         = $2001
PPU_STATUS            = $2002
PPU_SPR_ADDR          = $2003
PPU_SPR_DATA          = $2004
PPU_SCROLL_REG        = $2005
PPU_ADDRESS           = $2006
PPU_DATA              = $2007

SND_REGISTER          = $4000
SND_SQUARE1_REG       = $4000
SND_SQUARE2_REG       = $4004
SND_TRIANGLE_REG      = $4008
SND_NOISE_REG         = $400c
SND_DELTA_REG         = $4010
SND_MASTERCTRL_REG    = $4015

SPR_DMA               = $4014
CONTROLLER_PORT           = $4016
CONTROLLER_PORT1          = $4016
CONTROLLER_PORT2          = $4017

; ################################
; Game Tiles 0200 not used, used-> 0204->0228
; ################################

DISPLAY_NUMBERS_Y = 2
DISPLAY_P1_BP_HUNDREDS_TILE = $0205
DISPLAY_P1_BP_TENS_TILE = $0209
DISPLAY_P1_BP_ONES_TILE = $020D
DIPLAY_GT_TENS_TILES = $0211
DIPLAY_GT_ONES_TILES = $0215
DIPLAY_GT_TENTHS_TILES = $021D
DISPLAY_P2_BP_HUNDREDS_TILE = $0221
DISPLAY_P2_BP_TENS_TILE = $0225
DISPLAY_P2_BP_ONES_TILE = $0229

; ################################
; Menu Tiles 0200->?
; ################################

SCREEN_WIDTH_TILES = 32
SCREEN_HEIGHT_TILES = 30;
; -----------------------------------

  .rsset  $0000   ; start the reserve counter at memory address $0000
dummy .rs 1     ; theres some bug writing to 0000 which is game state...
game_state  .rs 1     ; reserve one byte of space to track the current state
prev_game_state .rs 1 ; to see if state has changed. could hide this in game state
GAME_TITLE = 1
GAME_MENU = 2
GAME_PLAY = 3
GAME_OVER = 4
GAME_SCROLL_TO_GAME = 5
GAME_SCROLL_TO_MENU = 6

GAME_OVER_WAIT_FRAMES = 120
game_over_frame_counter .rs 1

num_players .rs 1 ;

; What bit each button is stored in a controller byte
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001
BUTTON_NINJA  = %01000100

TOGGLE_BUTTONS = %11010011

p1_buttons   .rs 1  ; player 1 gamepad buttons, one bit per button
p2_buttons   .rs 1  ; player 2 gamepad buttons, one bit per button
p1_prev_buttons .rs 1 ; to track what buttons changed
p2_prev_buttons .rs 1 ; to track what buttons changed
p1_buttons_new_press .rs 1;
p2_buttons_new_press .rs 1;
p1_in_press .rs 1;
p2_in_press .rs 1;
start_pressed .rs 1 ; TODO this should really not take a full byte

p1_bp_counter_ones .rs 1;
p1_bp_counter_tens .rs 1;
p1_bp_counter_hundreds .rs 1;
p2_bp_counter_ones .rs 1;
p2_bp_counter_tens .rs 1;
p2_bp_counter_hundreds .rs 1;

menu_game_time_s_ones .rs 1
menu_game_time_s_tens .rs 1

FRAMES_PER_TENTH_SEC = 6 ; NTSC is 60 fps
less_than_tenth_sec_counter .rs 1

; Game seconds counter
game_timer_tenths .rs 1
game_timer_ones .rs 1
game_timer_tens .rs 1

mash_button .rs 1;
new_frame .rs 1;
scroll .rs 1;

; Menu values
NUM_PLAYERS_1_X = $70
NUM_PLAYERS_2_X = $88
NUM_PLAYER_CHOSER_X = $0207 ; Starts at 0204

REG_MENU_OPTION_CHOOSER_Y = $0200
REG_MENU_OPTION_CHOOSER_X = $0203
MENU_OPTION_CHOOSER_X = $30
MENU_NUM_PLAYERS_Y = $30
MENU_MASH_BUTTON_Y = $40
MENU_SECONDS_Y = $50
MENU_START_Y = $60


;;;;;;;;;;;;;;;

  .bank 0
  .org $C000
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX PPU_CTRL_REG1    ; disable NMI
  STX PPU_CTRL_REG2    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT PPU_STATUS
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT PPU_STATUS
  BPL vblankwait2

;MITCH
InitState:
  LDA #GAME_MENU
  STA game_state
  LDA #GAME_MENU ; TODO want states to disagree so that it'll load the first time
  STA prev_game_state

  JSR LoadMenu
  ; Don't ever overwrite background so just write them once
  JSR LoadMenuBackground
  JSR LoadGameBackground

  LDA #BUTTON_NINJA
  STA mash_button

; Set default value
  LDA #$05
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens

LoadPalettes:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS       ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA PPU_DATA          ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

; if compare was equal to 128, keep going down
LoadAttribute:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$23
  STA PPU_ADDRESS       ; write the high byte of $23C0 address
  LDA #$C0
  STA PPU_ADDRESS       ; write the low byte of $23C0 address
  LDX #$00              ; start out at 0
LoadAttributeLoop:
  LDA attribute, x      ; load data from address (attribute + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$08              ; Compare X to hex $08, decimal 8 - copying 8 bytes
  BNE LoadAttributeLoop

  JSR DisplayScreen0

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA PPU_CTRL_REG2

  LDA #$00
  STA scroll
  JSR PushScrollToPPU

Forever:
  LDA new_frame
  BNE ProcessFrame
  JMP Forever
ProcessFrame:
  LDA #00
  STA new_frame ; reset new frame
  LDA game_state
  CMP #GAME_SCROLL_TO_GAME
  BNE NotScrollingRight
  JSR IncrementScroll
  STX scroll
  CPX #$00
  BEQ DoneScrollingToGame
  JSR PushScrollToPPU
  JMP FrameProcessed
DoneScrollingToGame:
  LDA #GAME_PLAY
  STA game_state
  JSR PushScrollToPPU  ; Reset scroll to 0
  JSR DisplayScreen1   ; Set to display screen1
  JSR LoadGame         ; load game sprites
  JMP FrameProcessed
NotScrollingRight:
  LDA game_state
  CMP #GAME_SCROLL_TO_MENU
  BNE NotScrolling
  JSR DecrementScroll
  STX scroll
  CPX #$00
  BEQ DoneScrollingToMenu
  JSR PushScrollToPPU
  JMP FrameProcessed
DoneScrollingToMenu:
  LDA #GAME_MENU
  STA game_state
  JSR PushScrollToPPU  ; Reset scroll to 0
  JSR DisplayScreen0   ; Set to display screen 0
  JSR LoadMenu         ; load menu sprites
  JMP FrameProcessed
NotScrolling:
  LDA game_state
  CMP #GAME_PLAY
  BNE TryMenu
  JSR CalcGameTime        ; In game
  JSR CalcButtonPresses
  JSR DrawFrameCount
  JMP FrameProcessed
TryMenu:
  LDA game_state
  CMP #GAME_MENU
  BNE TryGameOver
  JSR MenuLogic
  JMP FrameProcessed
TryGameOver:
  LDA game_state
  CMP #GAME_OVER
  BNE FrameProcessed
  JSR GameOverLogic
  JMP FrameProcessed
FrameProcessed:
  JMP Forever     ;jump back to Forever, infinite loop

IncrementScroll:
  LDX scroll
  INX
  INX
  INX
  INX
  RTS

DecrementScroll:
  LDX scroll
  DEX
  DEX
  DEX
  DEX
  RTS

DisplayScreen0:
  LDA #%10011000
  STA PPU_CTRL_REG1
  RTS

DisplayScreen1:
  LDA #%10011001
  STA PPU_CTRL_REG1
  RTS

PushScrollToPPU:
  LDA #$00
  STA PPU_ADDRESS        ; clean up PPU address registers
  STA PPU_ADDRESS
  LDA scroll             ; horizontal scroll full
  STA PPU_SCROLL_REG
  LDA #$00               ; no vertical scrolling
  STA PPU_SCROLL_REG
  RTS

NMI:
  LDA #$00
  STA PPU_SPR_ADDR       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  JSR ReadController1
  JSR ReadController2

  LDA #01
  STA new_frame ; Tell forever loop that theres a new set of input to process

; TODO think it'd be better to just load it once and store result in A
GameLogic
  LDA game_state
  CMP #GAME_PLAY
  BEQ GameLogicPlay
  JMP EndGameLogic
GameLogicPlay:
  LDA game_timer_ones
  CMP menu_game_time_s_ones
  BNE EndGameLogic
  LDA menu_game_time_s_tens
  CMP game_timer_tens
  BNE EndGameLogic
  ;;;; Just hit the game over time so call the game over
  LDA #GAME_OVER
  STA game_state
EndGameLogic:
  RTI             ; return from interrupt

DrawFrameCount:
  LDA game_timer_tenths
  STA DIPLAY_GT_TENTHS_TILES
  LDA game_timer_ones
  STA DIPLAY_GT_ONES_TILES
  LDA game_timer_tens
  STA DIPLAY_GT_TENS_TILES
DrawButtonPresses:
  LDA p1_bp_counter_ones
  STA DISPLAY_P1_BP_ONES_TILE
  LDA p1_bp_counter_tens
  STA DISPLAY_P1_BP_TENS_TILE
  LDA p1_bp_counter_hundreds
  STA DISPLAY_P1_BP_HUNDREDS_TILE
  LDA p2_bp_counter_ones
  STA DISPLAY_P2_BP_ONES_TILE
  LDA p2_bp_counter_tens
  STA DISPLAY_P2_BP_TENS_TILE
  LDA p2_bp_counter_hundreds
  STA DISPLAY_P2_BP_HUNDREDS_TILE
  RTS

CalcButtonPresses:
  LDA p1_in_press
  CMP #$01
  BEQ CheckButtonUnPressed
  LDA p1_buttons
  AND mash_button
  CMP mash_button
  BNE P1DoneBPCalc ; branch if button not down
  LDA #$01
  STA p1_in_press ; button is pressed
  LDX p1_bp_counter_ones ; We have a new press
  INX
  STX p1_bp_counter_ones
  CPX #$0A
  BNE P1DoneBPCalc ; if we went over 9
  LDA #00
  STA p1_bp_counter_ones
  LDX p1_bp_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX p1_bp_counter_tens
  CPX #$0A
  BNE P1DoneBPCalc ; if we went over 99
  LDA #00
  STA p1_bp_counter_tens
  LDX p1_bp_counter_hundreds
  INX
  STX p1_bp_counter_hundreds
CheckButtonUnPressed:
  LDA p1_buttons
  AND mash_button
  BNE P1DoneBPCalc
  ;; buttons unpressed
  LDA #$00
  STA p1_in_press
P1DoneBPCalc:
  LDA p2_buttons_new_press
  AND mash_button
  BEQ P2DoneBPCalc ; branch if button not down
  LDX p2_bp_counter_ones ; We have a new press
  INX
  STX p2_bp_counter_ones
  CPX #$0A
  BNE P2DoneBPCalc ; if we went over 9
  LDA #00
  STA p2_bp_counter_ones
  LDX p2_bp_counter_tens
  INX ; TODO i think there might be a way to do this in place
  STX p2_bp_counter_tens
  CPX #$0A
  BNE P2DoneBPCalc ; if we went over 99
  LDA #00
  STA p2_bp_counter_tens
  LDX p2_bp_counter_hundreds
  INX
  STX p2_bp_counter_hundreds
P2DoneBPCalc:
  RTS

CalcGameTime:
  LDX less_than_tenth_sec_counter
  INX
  STX less_than_tenth_sec_counter
  CPX #FRAMES_PER_TENTH_SEC
  BNE DoneGameTimeCalc
  LDA #$00
  STA less_than_tenth_sec_counter
  LDX game_timer_tenths
  INX
  STX game_timer_tenths
  CPX #$0A
  BNE DoneGameTimeCalc ; if we went over 9
  LDA #00
  STA game_timer_tenths
  LDX game_timer_ones
  INX
  STX game_timer_ones
  CPX #$0A
  BNE DoneGameTimeCalc ; if we went over 99
  LDA #00
  STA game_timer_ones
  LDX game_timer_tens
  INX
  STX game_timer_tens
DoneGameTimeCalc:
  RTS

GameOverLogic:
  LDX game_over_frame_counter
  CPX #GAME_OVER_WAIT_FRAMES
  BEQ GameOverWaitDone
  INX
  STX game_over_frame_counter
  JMP GameOverLogicDone
GameOverWaitDone:
  LDA p1_buttons_new_press
  CMP #$00
  BEQ GameOverLogicDone
  ;; Wait is over and button is pressed so go back to menu
  LDA #GAME_SCROLL_TO_MENU
  STA game_state
  JSR MoveSpritesOffScreen
GameOverLogicDone:
  RTS

MenuLogic:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_MASH_BUTTON_Y
  BNE NotChoosingMashButton
  LDA #TOGGLE_BUTTONS
  AND p1_buttons_new_press
  BEQ NotChoosingMashButton
  JSR ToggleMashButton
  JMP MenuLogicDone
NotChoosingMashButton:
  LDA p1_buttons_new_press
  AND #BUTTON_SELECT
  BEQ NotToggleMenuButton
  JSR ToggleNextMenuItem ; just toggle menu button
  JMP MenuLogicDone
NotToggleMenuButton:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_NUM_PLAYERS_Y
  BNE NotToggleNumPlayers
  LDA #TOGGLE_BUTTONS
  AND p1_buttons_new_press
  BEQ NotToggleNumPlayers
  JSR ToggleNumPlayers
  JMP MenuLogicDone
NotToggleNumPlayers:
        ;TODO if button and AB/Start, go to choose mash button
NotMashButton:
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_SECONDS_Y
  BNE NotMenuSecondsOption
  LDA #BUTTON_LEFT
  ORA #BUTTON_B
  AND p1_buttons_new_press
  BEQ MenuSecOptionCheckIncrease
        ; Decrease
  LDX menu_game_time_s_ones
  CPX #$01
  BNE NotDecreaseTimeWrap
  LDA menu_game_time_s_tens
  CMP #$00
  BNE NotDecreaseTimeWrap
  ;; We're at 01 so wrap back to 60
  LDA #$00
  STA menu_game_time_s_ones
  LDA #$06
  STA menu_game_time_s_tens
  JMP MenuLogicDone
NotDecreaseTimeWrap:
  LDA menu_game_time_s_ones
  CMP #$00
  BNE MenuSecOptionDecreaseSimple
  ;; Already took care of the 01->60 case so safe to just wrap the tens
  LDA #$09
  STA menu_game_time_s_ones
  LDX menu_game_time_s_tens
  DEX
  STX menu_game_time_s_tens
  JMP MenuLogicDone
MenuSecOptionDecreaseSimple: ; Can just subtract one
  DEX
  STX menu_game_time_s_ones
  JMP MenuLogicDone
MenuSecOptionCheckIncrease:
  LDA #BUTTON_RIGHT
  ORA #BUTTON_A
  AND p1_buttons_new_press
  BEQ NotMenuSecondsOption
     ; Increase
  LDA menu_game_time_s_tens
  CMP #$06
  BNE MenuSecIncreaseNoFullWrap
  ; max value so go back to 1 second
  LDA #$01
  STA menu_game_time_s_ones
  LDA #$00
  STA menu_game_time_s_tens
  JMP MenuLogicDone
MenuSecIncreaseNoFullWrap:
  LDA menu_game_time_s_ones
  CMP #$09
  BNE MenuSecSimpleIncrease
  ; Wrap the tens
  LDA #$00
  STA menu_game_time_s_ones
  LDX menu_game_time_s_tens
  INX
  STX menu_game_time_s_tens
  JMP MenuLogicDone
MenuSecSimpleIncrease:
  LDX menu_game_time_s_ones
  INX
  STX menu_game_time_s_ones
  JMP MenuLogicDone
NotMenuSecondsOption:
  ;if start, if start, start
  LDA REG_MENU_OPTION_CHOOSER_Y
  CMP #MENU_START_Y
  BNE MenuLogicDone
  LDA p1_buttons_new_press
  AND #BUTTON_START
  BEQ MenuLogicDone
  LDA #GAME_SCROLL_TO_GAME ; start the game
  STA game_state
  JSR MoveSpritesOffScreen
  JMP MenuLogicDone
MenuLogicDone:
; TODO this stuff might be cleaner somewhere else
  LDA menu_game_time_s_ones
  STA $020D
  LDA menu_game_time_s_tens
  STA $0209
  RTS

ToggleNextMenuItem
  LDX REG_MENU_OPTION_CHOOSER_Y
  CPX #MENU_START_Y
  BEQ GoBackToFirstMenuItem
  LDA REG_MENU_OPTION_CHOOSER_Y
  ADC #$10 ; shift down 2 16 pixels
  STA REG_MENU_OPTION_CHOOSER_Y
  JMP DoneToggleNextMenuItem
GoBackToFirstMenuItem:
  LDA #MENU_NUM_PLAYERS_Y
  STA REG_MENU_OPTION_CHOOSER_Y
DoneToggleNextMenuItem:
  RTS

ToggleMashButton:
  JMP EndToggleMashButton ;; Only for ninja gaiden
  LDA mash_button
  CMP #BUTTON_A
  BNE ToggleMashButtonTryB
  JSR LoadMashButtonB
  JMP EndToggleMashButton
ToggleMashButtonTryB:
  CMP #BUTTON_B
  BNE ToggleMashButtonTryStart
  JSR LoadMashButtonStart
  JMP EndToggleMashButton
ToggleMashButtonTryStart:
  CMP #BUTTON_START
  BNE ToggleMashButtonTrySelect
  JSR LoadMashButtonSelect
  JMP EndToggleMashButton
ToggleMashButtonTrySelect
  JSR LoadMashButtonA
EndToggleMashButton:
  RTS

ToggleNumPlayers:
  LDA num_players
  CMP #$02
  BNE TwoPlayers
  ; from Two to One Player
  LDA #01
  STA num_players
  LDA #NUM_PLAYERS_1_X
  STA NUM_PLAYER_CHOSER_X
  JMP DoneTogglePlayers
TwoPlayers:
  ; from One to Two Player
  LDA #02
  STA num_players
  LDA #NUM_PLAYERS_2_X
  STA NUM_PLAYER_CHOSER_X
DoneTogglePlayers:
  RTS

LoadMenu:
  LDA #$01
  STA num_players
LoadMenuOptionChooser:
  LDA #MENU_NUM_PLAYERS_Y
  STA REG_MENU_OPTION_CHOOSER_Y
  LDA #$28 ; Arrow
  STA $0201 ; This whole block is a mess
  LDA #$00 ; attribute
  STA $0202
  LDA #$18 ; X position
  STA $0203
LoadNumPlayerArrow:
  LDX #$00              ; start at 0
LoadNumPlayerArrowLoop:
  LDA num_player_arrow, x        ; load data from address (sprites +  x)
  STA $0204, x                   ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$04              ;
  BNE LoadNumPlayerArrowLoop

LoadMenuGameTime:
  LDX #$00
LoadMenuGameTimeLoop:
  LDA menu_game_time, x
  STA $0208, x
  INX
  CPX #$08              ; 2 sprites (tens and ones)
  BNE LoadMenuGameTimeLoop

LoadMashButtonDisplay
  LDX #$00
LoadMashButtonDisplayLoop:
  LDA menu_button_choice, x
  STA $0210, x
  INX
  CPX #$18              ; 6 sprites (MAX word is 'select')
  BNE LoadMashButtonDisplayLoop

;TODO set this near to where we're setting the display
  JSR LoadMashButtonNinja
  RTS

LoadMenuBackground:
  LDA PPU_STATUS        ; read PPU status to reset the high/low latch
  LDA #$20
  STA PPU_ADDRESS       ; write the high byte of $2000 address
  LDA #$00
  STA PPU_ADDRESS       ; write the low byte of $2000 address
  LDX #$00              ; start out at 0
LoadMenuBackground1Loop:
  LDA menu_background_1, x; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground1Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground2Loop:
  LDA menu_background_2, x; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground2Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground3Loop:
  LDA menu_background_3, x; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$00              ; load all background tiles
  BNE LoadMenuBackground3Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
LoadMenuBackground4Loop:
  LDA menu_background_4, x; load data from address (background + the value in x)
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$C0              ; load all background tiles 6*32 = xC0
  BNE LoadMenuBackground4Loop  ; Branch to LoadBackgroundLoop if compare was Not Equal to zero
  RTS

LoadGameBackground:
  LDA PPU_STATUS
  LDA #$24
  STA PPU_ADDRESS
  LDA #$00
  STA PPU_ADDRESS
  LDX #$00
LoadGameBackground1Loop:
  LDA game_background_1, x
  STA $2007
  INX
  CPX #$00
  BNE LoadGameBackground1Loop
LoadGameBackground2Loop:
  LDA game_background_2, x
  STA $2007
  INX
  CPX #$00
  BNE LoadGameBackground2Loop
LoadGameBackground3Loop:
  LDA game_background_3, x
  STA $2007
  INX
  CPX #$00
  BNE LoadGameBackground3Loop
LoadGameBackground4Loop:
  LDA game_background_4, x
  STA $2007
  INX
  CPX #$C0
  BNE LoadGameBackground4Loop
  RTS

LoadGame:
  JSR MoveSpritesOffScreen ; TODO make sure this happens the same sort of way of going back to menu

  LDA #$00
  STA game_timer_tenths
  STA game_timer_ones
  STA game_timer_tens
  STA game_over_frame_counter
  STA p1_in_press
  STA p2_in_press

LoadP1Sprites:
  LDX #$00              ; start at 0
LoadP1SpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0204, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$1C              ; Compare X to hex $1C, decimal 28 -> 7 chars, 4 bytes each
  BNE LoadP1SpritesLoop

  LDA #$00
  STA p1_bp_counter_ones
  STA p1_bp_counter_tens
  STA p1_bp_counter_hundreds

  LDA num_players
  CMP #$02
  BNE SkipP2
LoadP2Sprites:
  LDX #$00              ; start at 0
LoadP2SpritesLoop:
  LDA p2_sprites, x        ; load data from address (sprites +  x)
  STA $0220, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$18              ; Compare X to hex $20, decimal 32
  BNE LoadP2SpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down

SkipP2:
LoadP1Label:
  LDX #$00
LoadP1LabelLoop:
  LDA p1_label, x
  STA $0238, x
  INX
  CPX #$0C
  BNE LoadP1LabelLoop

  RTS

; TODO there has to be a better way to do this
LoadMashButtonNinja
  LDA #BUTTON_NINJA
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonNinjaLoop:
  LDA ninja_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonNinjaLoop
  RTS

LoadMashButtonA
  LDA #BUTTON_A
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonALoop:
  LDA a_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonALoop
  RTS

LoadMashButtonB
  LDA #BUTTON_B
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonBLoop:
  LDA b_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonBLoop
  RTS

LoadMashButtonSelect
  LDA #BUTTON_SELECT
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonSelectLoop:
  LDA select_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonSelectLoop
  RTS

LoadMashButtonStart
  LDA #BUTTON_START
  STA mash_button
  LDX #$00
  LDY #$00
LoadMashButtonStartLoop:
  LDA start_text, x
  STA $0211, y
  INX
  INY
  INY
  INY
  INY ; There has to be a better way to do this
  CPX #$06
  BNE LoadMashButtonStartLoop
  RTS

MoveSpritesOffScreen:
  LDX #$00
  LDA #$F0                      ; Off screen in Y direction
MoveSpritesOffScreenLoop:
  STA $0200, x                  ; Put all sprites in a Y off screen position
  INX
  INX
  INX
  INX
  CPX #$00                      ; 0 == 256 -> 4*(64 sprites)
  BNE MoveSpritesOffScreenLoop
  RTS

ReadController1:
  LDA p1_buttons
  STA p1_prev_buttons ; backup the previous buttons
  LDA #$01
  STA CONTROLLER_PORT1
  LDA #$00
  STA CONTROLLER_PORT1
  LDX #$08
ReadController1Loop:
  LDA CONTROLLER_PORT1
  LSR A              ; bit0 -> Carry
  ROL p1_buttons     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  ; store what was newly pressed (not working)
  LDA p1_buttons
  EOR p1_prev_buttons
  AND p1_buttons
  STA p1_buttons_new_press
  RTS

ReadController2:
  LDA p2_buttons
  STA p2_prev_buttons ; backup the previous buttons
  LDA #$01
  STA CONTROLLER_PORT1
  LDA #$00
  STA CONTROLLER_PORT1
  LDX #$08
ReadController2Loop:
  LDA CONTROLLER_PORT2
  LSR A              ; bit0 -> Carry
  ROL p2_buttons     ; bit0 <- Carry
  DEX
  BNE ReadController2Loop
  ; store what was newly pressed (not working)
  LDA p2_buttons
  EOR p2_prev_buttons
  AND p2_buttons
  STA p2_buttons_new_press
  RTS

; ###############################
; Background/tile loading
; ###############################
  .bank 1
  .org $E000
palette:
  .db $0F,$30,$07,$16,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$30,$07,$16,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C

press_b_to_start:
  .db $19,$1B

sprites:
     ;vert tile attr horiz
  .db $50, $00, $00, $80   ;p1 hundreds bp count
  .db $50, $00, $00, $88   ;p1 tens bp count
  .db $50, $00, $00, $90   ;p1 ones bp count
  .db $60, $00, $00, $78   ;tens game timer
  .db $60, $00, $00, $80   ;ones game timer
  .db $60, $AF, $00, $88   ;decimal point
  .db $60, $00, $00, $90   ;tenths game timer

p2_sprites:
  .db $70, $00, $00, $80   ;p2 hundreds game timer
  .db $70, $00, $00, $88   ;p2 tens game timer
  .db $70, $00, $00, $90   ;p2 ones game timer
  .db $70, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $70, $02, $00, $68   ; '2'
  .db $70, $28, $00, $70   ; '-'

p1_label:
  .db $50, $19, $00, $60   ; 'p' TODO these should go in the background
  .db $50, $01, $00, $68   ; '1'
  .db $50, $28, $00, $70   ; '-'

num_player_arrow:
  .db $30, $28, $00, $70

menu_game_time
  .db $50, $01, $00, $88   ;tens
  .db $50, $02, $00, $90   ;ones

menu_button_choice
  .db $40, $0A, $00, $78
  .db $40, $0A, $00, $80
  .db $40, $0A, $00, $88
  .db $40, $0A, $00, $90
  .db $40, $0A, $00, $98
  .db $40, $0A, $00, $A0

up_text
  .db $1E, $19, $24, $24, $24, $24

down_text
  .db $0D, $18, $20, $17, $24, $24

left_text
  .db $15, $0E, $0F, $1D, $24, $24

right_text
  .db $1B, $12, $10, $11, $1D, $24

start_text:
  .db $1C, $1D, $0A, $1B, $1D, $24

select_text:
  .db $1C, $0E, $15, $0E, $0C, $1D

a_text
  .db $0A, $24, $24, $24, $24, $24

b_text
  .db $0B, $24, $24, $24, $24, $24

ninja_text
  .db $1E, $19, $29, $0B, $24, $24

menu_background_1:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 1
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 2
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 3
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 4
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 5
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 6
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$19,$15,$0A,$22,$0E,$1B,$1C,$24,$24,$24,$01  ;;row 7 Players
  .db $24,$24,$02,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 8
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
menu_background_2:
  .db $24,$24,$24,$24,$24,$24,$0B,$1E,$1D,$1D,$18,$17,$24,$24,$24,$24  ;;row 9 Button
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 10
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$1C,$0E,$0C,$18,$17,$0D,$1C,$24,$24,$24,$24  ;;row 11 Seconds
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 12
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$1C,$1D,$0A,$1B,$1D,$24,$24,$24,$24  ;;row 13 Start
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24  ;;row 14
  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 15
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 16
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
menu_background_3:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 17
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 18
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 19
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 20
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 21
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 22
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 23
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 24
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
menu_background_4:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 25
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 28
  .db $0A,$24,$16,$12,$1D,$0C,$11,$03,$0A,$F9,$10,$0A,$16,$0E,$FA,$24  ;; A Mitch3a Game
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 30
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24

game_background_1:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 1
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 2
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 3
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 4
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 5
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 6
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 7
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 8
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
game_background_2:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 9
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 10
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 11
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 12
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 13
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 14
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24,$24  ;;row 15
  .db $24,$24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$24,$24,$24,$24  ;;row 16
  .db $24,$24,$24,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
game_background_3:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 17
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 18
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 19
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 20
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 21
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 22
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 23
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 24
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
game_background_4:
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 25
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 27
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 28
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26  ;;row 29
  .db $24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24  ;;row 30
  .db $26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24,$26,$24
attribute:
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


;;;;;;;;;;;;;;


  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1
