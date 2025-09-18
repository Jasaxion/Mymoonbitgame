let random : @random.RandomState = @random.init_state()

let PHASE_TITLE : Int = 0
let PHASE_CHARACTER : Int = 1
let PHASE_DIFFICULTY : Int = 2
let PHASE_INTRO : Int = 3
let PHASE_BATTLE : Int = 4
let PHASE_RESULT : Int = 5

let SCREEN_WIDTH : Int = 160
let SCREEN_HEIGHT : Int = 160
let STAGE_FLOOR_Y : Int = 118
let FIGHTER_COUNT : Int = 3
let MAX_HP : Int = 100

pub struct Game {
  mut phase : Int,
  mut fighter_cursor : Int,
  mut difficulty_cursor : Int,
  mut intro_timer : Int,
  mut result_timer : Int,
  mut result_victory : Bool,
  mut prev_gamepad : @lib.GamePad,
  fight : FightState,
  mut menu_flash : Int,
  mut global_tick : Int,
}

pub fn Game::new() -> Game {
  {
    phase: PHASE_TITLE,
    fighter_cursor: 0,
    difficulty_cursor: 1,
    intro_timer: 0,
    result_timer: 0,
    result_victory: false,
    prev_gamepad: @lib.GamePad::default(),
    fight: FightState::new(),
    menu_flash: 0,
    global_tick: 0,
  }
}

pub fn Game::update(self : Game) -> Unit {
  let gamepad = @lib.get_gamepad()
  self.global_tick += 1
  self.menu_flash = (self.menu_flash + 1) % 120
  match self.phase {
    PHASE_TITLE => self.update_title(gamepad)
    PHASE_CHARACTER => self.update_character_select(gamepad)
    PHASE_DIFFICULTY => self.update_difficulty_select(gamepad)
    PHASE_INTRO => self.update_intro()
    PHASE_BATTLE => self.update_battle(gamepad)
    PHASE_RESULT => self.update_result(gamepad)
    _ => ()
  }
  self.prev_gamepad = gamepad
}

fn just_pressed(current : Bool, previous : Bool) -> Bool {
  current && previous.not()
}

fn clamp(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

fn clamp_position(x : Int) -> Int {
  clamp(x, 14, SCREEN_WIDTH - 14)
}

fn abs(value : Int) -> Int {
  if value < 0 { -value } else { value }
}

fn sign(value : Int) -> Int {
  if value > 0 {
    1
  } else if value < 0 {
    -1
  } else {
    0
  }
}

fn oscillate(timer : Int, amplitude : Int) -> Int {
  let span = amplitude * 4
  if span == 0 {
    0
  } else {
    let phase = timer % span
    if phase < amplitude * 2 {
      phase - amplitude
    } else {
      amplitude * 3 - phase
    }
  }
}

pub struct Combatant {
  fighter_id : Int,
  mut x : Int,
  mut hp : Int,
  mut facing : Int,
  mut attack_timer : Int,
  mut attack_cooldown : Int,
  mut hitstop : Int,
  mut block_timer : Int,
  mut step_cycle : Int,
  mut has_hit : Bool,
  mut slide_velocity : Int,
}

pub fn Combatant::new(fighter_id : Int, start_x : Int, facing : Int) -> Combatant {
  {
    fighter_id,
    x: start_x,
    hp: MAX_HP,
    facing,
    attack_timer: 0,
    attack_cooldown: 0,
    hitstop: 0,
    block_timer: 0,
    step_cycle: 0,
    has_hit: false,
    slide_velocity: 0,
  }
}

pub fn Combatant::reset(self : Combatant, fighter_id : Int, start_x : Int, facing : Int) -> Unit {
  self.fighter_id = fighter_id
  self.x = start_x
  self.hp = MAX_HP
  self.facing = facing
  self.attack_timer = 0
  self.attack_cooldown = 0
  self.hitstop = 0
  self.block_timer = 0
  self.step_cycle = 0
  self.has_hit = false
  self.slide_velocity = 0
}

pub fn Combatant::speed(self : Combatant) -> Int {
  fighter_speed(self.fighter_id)
}

pub fn Combatant::reach(self : Combatant) -> Int {
  fighter_reach(self.fighter_id)
}

pub fn Combatant::power(self : Combatant) -> Int {
  fighter_power(self.fighter_id)
}

pub fn Combatant::start_attack(self : Combatant) -> Unit {
  self.attack_timer = 14
  self.attack_cooldown = 22
  self.has_hit = false
}

pub fn Combatant::attack_active(self : Combatant) -> Bool {
  self.attack_timer > 4 && self.attack_timer <= 9
}

pub fn Combatant::set_block(self : Combatant, frames : Int) -> Unit {
  if self.block_timer < frames {
    self.block_timer = frames
  }
}

pub fn Combatant::apply_slide(self : Combatant) -> Unit {
  if self.slide_velocity != 0 {
    self.x = clamp_position(self.x + self.slide_velocity)
    if self.slide_velocity > 0 {
      self.slide_velocity -= 1
    } else {
      self.slide_velocity += 1
    }
  }
}

pub fn Combatant::tick_timers(self : Combatant) -> Unit {
  if self.attack_timer > 0 {
    self.attack_timer -= 1
    if self.attack_timer == 0 {
      self.has_hit = false
    }
  }
  if self.attack_cooldown > 0 {
    self.attack_cooldown -= 1
  }
  if self.block_timer > 0 {
    self.block_timer -= 1
  }
}

pub fn Combatant::take_damage(self : Combatant, damage : Int) -> Unit {
  self.hp = clamp(self.hp - damage, 0, MAX_HP)
}

pub struct FightState {
  mut player : Combatant,
  mut enemy : Combatant,
  mut difficulty : Int,
  mut round_time : Int,
  mut ai_timer : Int,
  mut ai_block_timer : Int,
  mut lantern_phase : Int,
  mut damage_flash : Int,
}

pub fn FightState::new() -> FightState {
  {
    player: Combatant::new(0, 52, 1),
    enemy: Combatant::new(1, 108, -1),
    difficulty: 1,
    round_time: 60 * 60,
    ai_timer: 20,
    ai_block_timer: 0,
    lantern_phase: 0,
    damage_flash: 0,
  }
}

pub fn FightState::reset(self : FightState, player_id : Int, enemy_id : Int, difficulty : Int) -> Unit {
  self.player.reset(player_id, 48, 1)
  self.enemy.reset(enemy_id, 112, -1)
  self.difficulty = difficulty
  self.round_time = 60 * 60
  self.ai_timer = difficulty_attack_interval(difficulty)
  self.ai_block_timer = 0
  self.lantern_phase = 0
  self.damage_flash = 0
}

pub fn FightState::update(self : FightState, gamepad : @lib.GamePad, prev : @lib.GamePad) -> Unit {
  self.lantern_phase += 1
  if self.damage_flash > 0 {
    self.damage_flash -= 1
  }
  if self.round_time > 0 {
    self.round_time -= 1
  }
  if self.player.x < self.enemy.x {
    self.player.facing = 1
    self.enemy.facing = -1
  } else {
    self.player.facing = -1
    self.enemy.facing = 1
  }
  if self.player.hitstop > 0 {
    self.player.hitstop -= 1
  } else {
    self.update_player_control(gamepad, prev)
  }
  if self.enemy.hitstop > 0 {
    self.enemy.hitstop -= 1
  } else {
    self.update_enemy_control()
  }
  self.player.apply_slide()
  self.enemy.apply_slide()
  self.player.tick_timers()
  self.enemy.tick_timers()
  self.resolve_player_attack()
  self.resolve_enemy_attack()
  self.draw_scene()
}

fn draw_scene_background(animation : Int) -> Unit {
  @lib.set_draw_colors(2)
  @lib.rect(0, 0, SCREEN_WIDTH, 68)
  @lib.set_draw_colors(4)
  @lib.rect(0, 68, SCREEN_WIDTH, 16)
  @lib.set_draw_colors(1)
  @lib.rect(0, 84, SCREEN_WIDTH, 12)
  @lib.set_draw_colors(3)
  @lib.rect(0, STAGE_FLOOR_Y, SCREEN_WIDTH, SCREEN_HEIGHT - STAGE_FLOOR_Y)
  @lib.set_draw_colors(4)
  @lib.rect(0, STAGE_FLOOR_Y + 18, SCREEN_WIDTH, SCREEN_HEIGHT - (STAGE_FLOOR_Y + 18))
  let sway = oscillate(animation, 3)
  @lib.set_draw_colors(1)
  @lib.line(16, 26 + sway, 144, 22 - sway)
  draw_lantern(36 + sway, 34, animation)
  draw_lantern(80 - sway, 32, animation + 20)
  draw_lantern(124 + sway, 34, animation + 40)
  draw_willow(14, 36, animation)
  draw_ducks(62, STAGE_FLOOR_Y + 22, animation)
}

pub fn FightState::draw_scene(self : FightState) -> Unit {
  draw_scene_background(self.lantern_phase)
  draw_stage_floor_details()
  draw_combatant(self.player, true)
  draw_combatant(self.enemy, false)
  draw_ui(self)
  if self.damage_flash > 0 {
    @lib.set_draw_colors(3)
    @lib.rect(0, 0, SCREEN_WIDTH, 2)
  }
}

fn draw_stage_floor_details() -> Unit {
  @lib.set_draw_colors(1)
  @lib.rect(0, STAGE_FLOOR_Y - 4, SCREEN_WIDTH, 4)
  let mut offset = 0
  while offset < SCREEN_WIDTH {
    @lib.set_draw_colors(2)
    @lib.rect(offset, STAGE_FLOOR_Y - 6, 6, 2)
    offset += 12
  }
}

fn draw_combatant(combatant : Combatant, is_player : Bool) -> Unit {
  let base_y = STAGE_FLOOR_Y - 2
  let step = combatant.step_cycle % 8
  let bob = if combatant.attack_timer > 0 { 0 } else { step / 4 }
  let y = base_y - bob
  draw_fighter_form(
    combatant.fighter_id,
    combatant.x,
    y,
    combatant.facing,
    combatant.attack_timer,
    combatant.block_timer,
    combatant.hitstop,
    is_player,
  )
}

fn draw_ui(state : FightState) -> Unit {
  draw_health_bar(10, 8, state.player.hp, 4)
  draw_health_bar(SCREEN_WIDTH - 62, 8, state.enemy.hp, 3)
  @lib.set_draw_colors(1)
  @lib.text(fighter_name(state.player.fighter_id), 12, 18)
  @lib.text(fighter_name(state.enemy.fighter_id), SCREEN_WIDTH - 60, 18)
  @lib.text(difficulty_name(state.difficulty), 66, 8)
}

fn draw_health_bar(x : Int, y : Int, hp : Int, color : Int) -> Unit {
  @lib.set_draw_colors(1)
  @lib.rect(x - 1, y - 1, 54, 9)
  @lib.set_draw_colors(2)
  @lib.rect(x, y, 52, 7)
  let width = hp * 52 / MAX_HP
  @lib.set_draw_colors(color)
  @lib.rect(x, y, width, 7)
}

fn draw_fighter_form(
  fighter_id : Int,
  x : Int,
  y : Int,
  facing : Int,
  attack_timer : Int,
  block_timer : Int,
  hitstop : Int,
  is_player : Bool,
) -> Unit {
  let top = y - 24
  @lib.set_draw_colors(1)
  @lib.rect(x - 8, top, 16, 24)
  @lib.set_draw_colors(2)
  @lib.rect(x - 7, top + 1, 14, 22)
  let cloth_color = fighter_cloth_color(fighter_id)
  @lib.set_draw_colors(cloth_color)
  @lib.rect(x - 7, top + 11, 14, 5)
  let accent_color = fighter_accent_color(fighter_id)
  match fighter_id {
    0 => { // Kung Fu Panda
      @lib.set_draw_colors(1)
      @lib.rect(x - 5, top + 3, 3, 3)
      @lib.rect(x + 2, top + 3, 3, 3)
      @lib.set_draw_colors(accent_color)
      @lib.rect(x - 2, top + 14, 4, 2)
      @lib.set_draw_colors(4)
      @lib.rect(x + facing * 6 - 2, top + 13, 3, 8)
    }
    1 => { // Sun Wukong
      @lib.set_draw_colors(accent_color)
      @lib.rect(x - 6, top + 2, 12, 2)
      @lib.set_draw_colors(1)
      @lib.rect(x - 4, top + 4, 2, 2)
      @lib.rect(x + 2, top + 4, 2, 2)
      @lib.set_draw_colors(4)
      @lib.rect(x + facing * 10 - 1, top + 8, 2, 18)
    }
    _ => { // Nezha
      @lib.set_draw_colors(accent_color)
      @lib.rect(x - 7, top + 5, 3, 3)
      @lib.rect(x + 4, top + 5, 3, 3)
      @lib.set_draw_colors(4)
      @lib.rect(x + facing * 7 - 1, top + 7, 2, 14)
    }
  }
  if block_timer > 0 {
    @lib.set_draw_colors(accent_color)
    @lib.rect(x + facing * 6 - 3, top + 6, 6, 12)
  }
  if attack_timer > 4 {
    let reach = fighter_reach(fighter_id)
    let punch_length = 6 + reach / 3
    @lib.set_draw_colors(cloth_color)
    @lib.rect(x + facing * (8 + reach / 4) - punch_length / 2, top + 14, punch_length, 4)
    if fighter_id == 1 {
      @lib.set_draw_colors(accent_color)
      @lib.rect(x + facing * (12 + reach / 4), top + 12, 3, 6)
    }
  }
  if hitstop > 0 {
    @lib.set_draw_colors(3)
    @lib.rect(x - 9, top - 2, 18, 2)
  }
  if is_player {
    @lib.set_draw_colors(4)
    @lib.rect(x - 6, y + 2, 12, 2)
  }
}

fn draw_lantern(x : Int, y : Int, timer : Int) -> Unit {
  let swing = oscillate(timer, 2)
  @lib.set_draw_colors(1)
  @lib.line(x + swing, y - 8, x + swing, y - 2)
  @lib.set_draw_colors(3)
  @lib.rect(x + swing - 3, y - 2, 6, 6)
  @lib.set_draw_colors(2)
  @lib.rect(x + swing - 3, y, 6, 2)
  @lib.set_draw_colors(1)
  @lib.line(x + swing, y + 4, x + swing, y + 8)
}

fn draw_willow(x : Int, y : Int, timer : Int) -> Unit {
  @lib.set_draw_colors(1)
  @lib.rect(x - 1, y, 3, 32)
  let sway = oscillate(timer + 10, 4)
  let mut branch = 0
  while branch < 3 {
    @lib.set_draw_colors(4)
    let offset = branch * 6
    @lib.rect(x - 6 - sway + branch * 2, y + 8 + offset, 2, 12)
    @lib.rect(x + 4 + sway - branch * 2, y + 10 + offset, 2, 12)
    branch += 1
  }
}

fn draw_ducks(x : Int, y : Int, timer : Int) -> Unit {
  let bob = oscillate(timer + 30, 2)
  @lib.set_draw_colors(2)
  @lib.rect(x - 6, y + bob, 12, 6)
  @lib.set_draw_colors(3)
  @lib.rect(x - 8, y + bob + 2, 2, 2)
  @lib.rect(x + 6, y + bob + 1, 2, 2)
  @lib.set_draw_colors(2)
  @lib.rect(x + 12, y + bob + 2, 10, 5)
  @lib.set_draw_colors(3)
  @lib.rect(x + 20, y + bob + 3, 3, 2)
}

fn fighter_name(index : Int) -> @string.String {
  match index {
    0 => "Kung Fu Panda"
    1 => "Sun Wukong"
    _ => "Nezha"
  }
}

fn fighter_story_line(index : Int) -> @string.String {
  match index {
    0 => "Bamboo guardian with heavy palms"
    1 => "Great Sage, agile staff master"
    _ => "Lotus warrior dancing with ribbons"
  }
}

fn fighter_story_detail(index : Int) -> @string.String {
  match index {
    0 => "Slow but mighty strikes"
    1 => "Fast combos and long reach"
    _ => "Balanced speed and counters"
  }
}

fn fighter_cloth_color(index : Int) -> Int {
  match index {
    0 => 3
    1 => 4
    _ => 3
  }
}

fn fighter_accent_color(index : Int) -> Int {
  match index {
    0 => 4
    1 => 3
    _ => 4
  }
}

fn fighter_speed(index : Int) -> Int {
  match index {
    0 => 2
    1 => 3
    _ => 2
  }
}

fn fighter_reach(index : Int) -> Int {
  match index {
    0 => 18
    1 => 24
    _ => 20
  }
}

fn fighter_power(index : Int) -> Int {
  match index {
    0 => 16
    1 => 12
    _ => 14
  }
}

fn difficulty_name(index : Int) -> @string.String {
  match index {
    0 => "Beginnings"
    1 => "Warrior"
    _ => "Grandmaster"
  }
}

fn difficulty_desc(index : Int) -> @string.String {
  match index {
    0 => "PC waits and moves slowly"
    1 => "Balanced rhythm"
    _ => "Aggressive relentless foe"
  }
}

fn difficulty_attack_interval(index : Int) -> Int {
  match index {
    0 => 42
    1 => 28
    _ => 16
  }
}

fn difficulty_block_chance(index : Int) -> Int {
  match index {
    0 => 20
    1 => 45
    _ => 75
  }
}

fn difficulty_speed_bonus(index : Int) -> Int {
  match index {
    0 => 0
    1 => 1
    _ => 1
  }
}

fn difficulty_damage_bonus(index : Int) -> Int {
  match index {
    0 => 0
    1 => 2
    _ => 4
  }
}

fn draw_menu_header(title : @string.String, subtitle : @string.String, timer : Int) -> Unit {
  draw_scene_background(timer)
  @lib.set_draw_colors(3)
  @lib.text(title, 28, 18)
  @lib.set_draw_colors(1)
  @lib.text(subtitle, 12, 32)
}

fn draw_selection_cursor(x : Int, y : Int, active : Bool) -> Unit {
  if active {
    @lib.set_draw_colors(4)
    @lib.rect(x - 20, y - 26, 40, 52)
  }
  @lib.set_draw_colors(1)
  @lib.rect(x - 18, y - 24, 36, 48)
  @lib.set_draw_colors(2)
  @lib.rect(x - 17, y - 23, 34, 46)
}

fn draw_fighter_preview(id : Int, x : Int, y : Int, facing : Int) -> Unit {
  draw_fighter_form(id, x, y, facing, 0, 0, 0, true)
}

pub fn Game::update_title(self : Game, gamepad : @lib.GamePad) -> Unit {
  draw_scene_background(self.global_tick)
  @lib.set_draw_colors(3)
  @lib.text("Lantern Clash", 32, 22)
  @lib.set_draw_colors(1)
  @lib.text("A MoonBit Wukong Fighter", 12, 40)
  @lib.text("Move: Arrow Keys", 30, 60)
  @lib.text("Attack: Z | Guard: X", 22, 70)
  let flash = self.menu_flash < 60
  if flash {
    @lib.set_draw_colors(4)
  } else {
    @lib.set_draw_colors(1)
  }
  @lib.text("Press Z to enter", 28, 90)
  if just_pressed(gamepad.button_1, self.prev_gamepad.button_1) {
    self.phase = PHASE_CHARACTER
    self.menu_flash = 0
  }
}

pub fn Game::update_character_select(self : Game, gamepad : @lib.GamePad) -> Unit {
  draw_menu_header("Choose Your Hero", "Left/Right to select", self.global_tick)
  let mut index = 0
  while index < FIGHTER_COUNT {
    let x = 40 + index * 40
    let active = index == self.fighter_cursor
    draw_selection_cursor(x, 88, active)
    draw_fighter_preview(index, x, 96, 1)
    @lib.set_draw_colors(1)
    @lib.text(fighter_name(index), x - 16, 122)
    index += 1
  }
  @lib.set_draw_colors(3)
  @lib.text(fighter_story_line(self.fighter_cursor), 12, 134)
  @lib.set_draw_colors(1)
  @lib.text(fighter_story_detail(self.fighter_cursor), 12, 144)
  if just_pressed(gamepad.button_left, self.prev_gamepad.button_left) {
    self.fighter_cursor = (self.fighter_cursor + FIGHTER_COUNT - 1) % FIGHTER_COUNT
  }
  if just_pressed(gamepad.button_right, self.prev_gamepad.button_right) {
    self.fighter_cursor = (self.fighter_cursor + 1) % FIGHTER_COUNT
  }
  if just_pressed(gamepad.button_1, self.prev_gamepad.button_1) {
    self.phase = PHASE_DIFFICULTY
  }
  if just_pressed(gamepad.button_2, self.prev_gamepad.button_2) {
    self.phase = PHASE_TITLE
  }
}

pub fn Game::update_difficulty_select(self : Game, gamepad : @lib.GamePad) -> Unit {
  draw_menu_header("Select Challenge", "Z confirm, X back", self.global_tick)
  let mut index = 0
  while index < 3 {
    let y = 60 + index * 28
    if index == self.difficulty_cursor {
      @lib.set_draw_colors(4)
      @lib.rect(12, y - 4, SCREEN_WIDTH - 24, 24)
    }
    @lib.set_draw_colors(1)
    @lib.text(difficulty_name(index), 24, y)
    @lib.set_draw_colors(3)
    @lib.text(difficulty_desc(index), 24, y + 10)
    index += 1
  }
  if just_pressed(gamepad.button_up, self.prev_gamepad.button_up) {
    self.difficulty_cursor = clamp(self.difficulty_cursor - 1, 0, 2)
  }
  if just_pressed(gamepad.button_down, self.prev_gamepad.button_down) {
    self.difficulty_cursor = clamp(self.difficulty_cursor + 1, 0, 2)
  }
  if just_pressed(gamepad.button_1, self.prev_gamepad.button_1) {
    self.start_battle()
  }
  if just_pressed(gamepad.button_2, self.prev_gamepad.button_2) {
    self.phase = PHASE_CHARACTER
  }
}

fn pick_enemy(player_choice : Int) -> Int {
  let mut enemy = random.gen_int().abs() % FIGHTER_COUNT
  if enemy == player_choice {
    enemy = (enemy + 1) % FIGHTER_COUNT
  }
  enemy
}

pub fn Game::start_battle(self : Game) -> Unit {
  let enemy_id = pick_enemy(self.fighter_cursor)
  self.fight.reset(self.fighter_cursor, enemy_id, self.difficulty_cursor)
  self.phase = PHASE_INTRO
  self.intro_timer = 90
}

pub fn Game::update_intro(self : Game) -> Unit {
  draw_scene_background(self.global_tick)
  draw_stage_floor_details()
  draw_fighter_form(self.fight.player.fighter_id, 56, STAGE_FLOOR_Y - 2, 1, 0, 0, 0, true)
  draw_fighter_form(self.fight.enemy.fighter_id, SCREEN_WIDTH - 56, STAGE_FLOOR_Y - 2, -1, 0, 0, 0, false)
  @lib.set_draw_colors(3)
  @lib.text("VS", 74, 64)
  @lib.set_draw_colors(1)
  @lib.text(fighter_name(self.fight.player.fighter_id), 20, 82)
  @lib.text(fighter_name(self.fight.enemy.fighter_id), SCREEN_WIDTH - 96, 82)
  @lib.text(difficulty_name(self.difficulty_cursor), 52, 96)
  self.intro_timer -= 1
  if self.intro_timer <= 0 {
    self.phase = PHASE_BATTLE
  }
}

pub fn Game::update_battle(self : Game, gamepad : @lib.GamePad) -> Unit {
  self.fight.update(gamepad, self.prev_gamepad)
  if self.fight.player.hp == 0 {
    self.end_round(false)
  } else if self.fight.enemy.hp == 0 {
    self.end_round(true)
  } else if self.fight.round_time == 0 {
    let victory = self.fight.player.hp >= self.fight.enemy.hp
    self.end_round(victory)
  }
}

pub fn Game::end_round(self : Game, victory : Bool) -> Unit {
  self.result_victory = victory
  self.phase = PHASE_RESULT
  self.result_timer = 30
}

pub fn Game::update_result(self : Game, gamepad : @lib.GamePad) -> Unit {
  draw_scene_background(self.global_tick)
  draw_stage_floor_details()
  @lib.set_draw_colors(1)
  if self.result_victory {
    @lib.text("Victory!", 48, 40)
    @lib.set_draw_colors(4)
    @lib.text("Peace returns to the lantern plaza", 8, 56)
  } else {
    @lib.set_draw_colors(3)
    @lib.text("Defeat", 56, 40)
    @lib.set_draw_colors(1)
    @lib.text("Train harder and try again", 16, 56)
  }
  @lib.set_draw_colors(1)
  @lib.text("Z: rematch  X: menu", 30, 80)
  if self.result_timer > 0 {
    self.result_timer -= 1
  } else {
    if just_pressed(gamepad.button_1, self.prev_gamepad.button_1) {
      self.start_battle()
    }
    if just_pressed(gamepad.button_2, self.prev_gamepad.button_2) {
      self.phase = PHASE_CHARACTER
    }
  }
}

fn apply_hit(
  attacker : Combatant,
  defender : Combatant,
  damage_bonus : Int,
  push : Int,
  flash : Bool,
) -> Unit {
  let base_damage = attacker.power() + damage_bonus
  if defender.block_timer > 0 {
    let blocked = clamp(base_damage / 3, 1, base_damage)
    defender.take_damage(blocked)
    defender.slide_velocity = -attacker.facing * (push / 2)
  } else {
    defender.take_damage(base_damage)
    defender.hitstop = 10
    defender.slide_velocity = -attacker.facing * push
    if flash {
      // handled by caller via damage_flash field
    }
  }
  attacker.attack_timer = 4
  attacker.has_hit = true
}

pub fn FightState::resolve_player_attack(self : FightState) -> Unit {
  if self.player.attack_active() && self.player.has_hit.not() {
    let distance = abs(self.player.x - self.enemy.x)
    if distance < self.player.reach() {
      apply_hit(self.player, self.enemy, 0, 6, true)
      self.damage_flash = 4
      self.ai_timer = difficulty_attack_interval(self.difficulty)
    }
  }
}

pub fn FightState::resolve_enemy_attack(self : FightState) -> Unit {
  if self.enemy.attack_active() && self.enemy.has_hit.not() {
    let distance = abs(self.player.x - self.enemy.x)
    if distance < self.enemy.reach() {
      let bonus = difficulty_damage_bonus(self.difficulty)
      apply_hit(self.enemy, self.player, bonus, 5, false)
    }
  }
}

pub fn FightState::update_player_control(self : FightState, gamepad : @lib.GamePad, prev : @lib.GamePad) -> Unit {
  let mut direction = 0
  if gamepad.button_left { direction -= 1 }
  if gamepad.button_right { direction += 1 }
  if direction != 0 {
    self.player.x = clamp_position(self.player.x + direction * self.player.speed())
    self.player.step_cycle = (self.player.step_cycle + 1) % 16
  }
  if gamepad.button_2 {
    self.player.set_block(6)
  }
  if just_pressed(gamepad.button_1, prev.button_1) && self.player.attack_timer == 0 && self.player.attack_cooldown == 0 {
    self.player.start_attack()
  }
}

pub fn FightState::update_enemy_control(self : FightState) -> Unit {
  let distance = self.player.x - self.enemy.x
  let abs_distance = abs(distance)
  let mut direction = 0
  if abs_distance > self.enemy.reach() + 10 {
    direction = sign(distance)
  } else if abs_distance < self.enemy.reach() - 4 {
    direction = -sign(distance)
  }
  let speed = self.enemy.speed() + difficulty_speed_bonus(self.difficulty)
  if direction != 0 {
    self.enemy.x = clamp_position(self.enemy.x + direction * speed)
    self.enemy.step_cycle = (self.enemy.step_cycle + 1) % 16
  }
  if self.ai_block_timer > 0 {
    self.ai_block_timer -= 1
  }
  if self.ai_timer > 0 {
    self.ai_timer -= 1
  } else if self.enemy.attack_timer == 0 && self.enemy.attack_cooldown == 0 {
    if abs_distance < self.enemy.reach() + 6 {
      self.enemy.start_attack()
    }
    self.ai_timer = difficulty_attack_interval(self.difficulty)
  }
  if self.player.attack_active() && abs_distance < self.player.reach() + 6 && self.ai_block_timer == 0 {
    let chance = random.gen_int().abs() % 100
    if chance < difficulty_block_chance(self.difficulty) {
      self.enemy.set_block(8)
      self.ai_block_timer = 30
    }
  }
  if self.enemy.block_timer == 0 && abs_distance > self.enemy.reach() + 20 {
    let dash_chance = random.gen_int().abs() % 120
    if dash_chance == 0 {
      self.enemy.x = clamp_position(self.enemy.x + sign(distance) * (6 + speed))
    }
  }
}

