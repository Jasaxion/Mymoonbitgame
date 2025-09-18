pub fn start() -> Unit {
  @lib.set_palette(1, @lib.rgb(0x101728))
  @lib.set_palette(2, @lib.rgb(0xf2e7d5))
  @lib.set_palette(3, @lib.rgb(0xd4483b))
  @lib.set_palette(4, @lib.rgb(0x4ea577))
}

let game : Game = Game::new()

pub fn upd() -> Unit {
  game.update()
}
