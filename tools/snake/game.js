(() => {
  const GRID = 16;
  const CELL = 30; // 16 * 30 = 480 canvas
  const TICK_MS = 140;
  const BOOST = 1.25;

  const canvas = document.getElementById("board");
  const ctx = canvas.getContext("2d");
  const scoreEl = document.getElementById("score");
  const lengthEl = document.getElementById("length");
  const statusEl = document.getElementById("status");
  const btnStart = document.getElementById("btn-start");

  const DIRS = {
    up: { x: 0, y: -1 },
    down: { x: 0, y: 1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  };

  const OPPOSITE = {
    up: "down",
    down: "up",
    left: "right",
    right: "left",
  };

  let snake;
  let dir;
  let nextDir;
  let food;
  let score;
  let running;
  let paused;
  let dead;
  let boosting;
  let timer;

  function reset() {
    const mid = Math.floor(GRID / 2);
    snake = [
      { x: mid, y: mid },
      { x: mid - 1, y: mid },
      { x: mid - 2, y: mid },
    ];
    dir = "right";
    nextDir = "right";
    score = 0;
    running = false;
    paused = false;
    dead = false;
    boosting = false;
    food = spawnFood();
    updateHud();
    setStatus("按开始或 Enter 开始游戏");
    draw();
  }

  function tickInterval() {
    return boosting ? TICK_MS / BOOST : TICK_MS;
  }

  function syncTimer() {
    clearInterval(timer);
    timer = null;
    if (!running || dead) return;
    timer = setInterval(step, tickInterval());
  }

  function spawnFood() {
    const occupied = new Set(snake.map((p) => `${p.x},${p.y}`));
    const free = [];
    for (let y = 0; y < GRID; y++) {
      for (let x = 0; x < GRID; x++) {
        const key = `${x},${y}`;
        if (!occupied.has(key)) free.push({ x, y });
      }
    }
    if (free.length === 0) return null;
    const pos = free[Math.floor(Math.random() * free.length)];
    // 约 80% 红(+1)，20% 蓝(+2)
    const kind = Math.random() < 0.2 ? "blue" : "red";
    return { x: pos.x, y: pos.y, kind };
  }

  function updateHud() {
    scoreEl.textContent = String(score);
    lengthEl.textContent = String(snake.length);
  }

  function setStatus(text, kind = "") {
    statusEl.textContent = text;
    statusEl.className = "status" + (kind ? ` ${kind}` : "");
  }

  function drawCell(x, y, color) {
    const pad = 1;
    ctx.fillStyle = color;
    ctx.fillRect(x * CELL + pad, y * CELL + pad, CELL - pad * 2, CELL - pad * 2);
  }

  function draw() {
    ctx.fillStyle = "#243028";
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    ctx.strokeStyle = "#1a221c";
    ctx.lineWidth = 1;
    for (let i = 0; i <= GRID; i++) {
      ctx.beginPath();
      ctx.moveTo(i * CELL + 0.5, 0);
      ctx.lineTo(i * CELL + 0.5, canvas.height);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, i * CELL + 0.5);
      ctx.lineTo(canvas.width, i * CELL + 0.5);
      ctx.stroke();
    }

    if (food) {
      drawCell(food.x, food.y, food.kind === "blue" ? "#4c8be8" : "#e85d4c");
    }

    snake.forEach((seg, i) => {
      drawCell(seg.x, seg.y, i === 0 ? "#a8e6a1" : "#6fbf73");
    });
  }

  function step() {
    if (!running || paused || dead) return;

    dir = nextDir;
    const head = snake[0];
    const d = DIRS[dir];
    const nx = head.x + d.x;
    const ny = head.y + d.y;

    if (nx < 0 || nx >= GRID || ny < 0 || ny >= GRID) {
      gameOver();
      return;
    }

    const hitSelf = snake.some((s) => s.x === nx && s.y === ny);
    if (hitSelf) {
      gameOver();
      return;
    }

    const newHead = { x: nx, y: ny };
    snake.unshift(newHead);

    if (food && newHead.x === food.x && newHead.y === food.y) {
      score += food.kind === "blue" ? 2 : 1;
      food = spawnFood();
      if (!food) {
        // 场地被蛇占满
        updateHud();
        draw();
        win();
        return;
      }
    } else {
      snake.pop();
    }

    updateHud();
    draw();
  }

  function gameOver() {
    dead = true;
    running = false;
    clearInterval(timer);
    timer = null;
    setStatus("撞到了！按 Enter 或开始重来", "over");
    btnStart.textContent = "重来";
    draw();
  }

  function win() {
    dead = true;
    running = false;
    clearInterval(timer);
    timer = null;
    setStatus("通关！蛇占满了整个场地", "pause");
    btnStart.textContent = "重来";
  }

  function start() {
    if (dead || !running) {
      reset();
      running = true;
      dead = false;
      paused = false;
      btnStart.textContent = "暂停";
      setStatus("游戏中…");
      syncTimer();
      return;
    }

    paused = !paused;
    if (paused) {
      btnStart.textContent = "继续";
      setStatus("已暂停", "pause");
    } else {
      btnStart.textContent = "暂停";
      setStatus("游戏中…");
    }
  }

  function queueDir(name) {
    if (dead || !running) return;
    if (OPPOSITE[dir] === name) return;
    nextDir = name;
  }

  const keyMap = {
    ArrowUp: "up",
    ArrowDown: "down",
    ArrowLeft: "left",
    ArrowRight: "right",
    w: "up",
    W: "up",
    s: "down",
    S: "down",
    a: "left",
    A: "left",
    d: "right",
    D: "right",
  };

  function setBoost(on) {
    if (boosting === on) return;
    boosting = on;
    if (running && !dead) syncTimer();
  }

  window.addEventListener("keydown", (e) => {
    if (e.key === "Shift" || e.code === "ShiftLeft" || e.code === "ShiftRight") {
      setBoost(true);
      return;
    }
    if (e.key === " " || e.code === "Space") {
      e.preventDefault();
      if (running && !dead) start();
      return;
    }
    if (e.key === "Enter") {
      e.preventDefault();
      if (!running || dead) start();
      return;
    }
    const mapped = keyMap[e.key];
    if (mapped) {
      e.preventDefault();
      queueDir(mapped);
    }
  });

  window.addEventListener("keyup", (e) => {
    if (e.key === "Shift" || e.code === "ShiftLeft" || e.code === "ShiftRight") {
      setBoost(false);
    }
  });

  window.addEventListener("blur", () => setBoost(false));

  btnStart.addEventListener("click", start);

  const touchPad = document.querySelector(".touch-pad");
  if (touchPad) {
    touchPad.addEventListener(
      "pointerdown",
      (e) => {
        const btn = e.target.closest(".pad-btn");
        if (!btn) return;
        e.preventDefault();
        btn.classList.add("is-active");
        if (btn.hasAttribute("data-boost")) {
          setBoost(true);
          return;
        }
        const dirName = btn.getAttribute("data-dir");
        if (dirName) queueDir(dirName);
      },
      { passive: false }
    );

    const clearBoostPad = (e) => {
      const btn = e.target.closest(".pad-btn");
      if (!btn) return;
      btn.classList.remove("is-active");
      if (btn.hasAttribute("data-boost")) setBoost(false);
    };

    touchPad.addEventListener("pointerup", clearBoostPad);
    touchPad.addEventListener("pointercancel", clearBoostPad);
    touchPad.addEventListener("pointerleave", (e) => {
      if (e.target.closest?.("[data-boost]")) {
        e.target.closest(".pad-btn")?.classList.remove("is-active");
        setBoost(false);
      }
    });
  }

  reset();
})();
