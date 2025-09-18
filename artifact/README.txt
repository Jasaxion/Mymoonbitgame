Lantern Clash WASM 构建说明
===========================

1. 在仓库根目录执行 `moon build --target wasm` 生成 `target/wasm/release/build/lantern-clash.wasm`。
2. 将生成的 wasm 文件复制为 `artifact/game.wasm`，即可通过 `artifact/index.html` 在浏览器中直接试玩。
3. 如需打包单文件版本，可使用 `npx wasm4 bundle --html artifact/index.html target/wasm/release/build/lantern-clash.wasm`。

提示：本仓库附带的 `wasm4.js`、`wasm4.css`、`wasm4.js.map` 已准备好，无需额外下载。
