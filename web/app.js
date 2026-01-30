const app = document.getElementById("app");
const uiCountdown = document.getElementById("uiCountdown");
const uiStreak = document.getElementById("uiStreak");

const cardsContainer = document.getElementById("cardsContainer");
const streakDots = document.getElementById("streakDots");

const btnClose = document.getElementById("btnClose");
const btnClaim = document.getElementById("btnClaim");
const btnClaimText = document.getElementById("btnClaimText");
const btnClaimIcon = document.getElementById("btnClaimIcon");

const uiPlayerNameEl = document.querySelector(".pname");
const uiPlanEl = document.querySelector(".psub");

let STATE = null;
function resourceName() {
  try { return GetParentResourceName(); } catch { return "rs_dailygift"; }
}

function inventoryImageCandidates(itemName) {
  return [
    `nui://ox_inventory/web/images/${itemName}.png`,
    `nui://qb-inventory/html/images/${itemName}.png`,
    `nui://ps-inventory/html/images/${itemName}.png`,
    `nui://qs-inventory/html/images/${itemName}.png`,
    `nui://${resourceName()}/web/images/${itemName}.png`,
  ];
}

function moneyImageCandidates(account) {
  const file = (account && account.toLowerCase() === 'money') ? 'bank' : 'money';

  return [
    `nui://ox_inventory/web/images/${file}.png`,
    `nui://qb-inventory/html/images/${file}.png`,
    `nui://ps-inventory/html/images/${file}.png`,
    `nui://qs-inventory/html/images/${file}.png`,
    `nui://${resourceName()}/web/images/${file}.png`,
  ];
}

function makeMoneyImg(account) {
  const img = document.createElement('img');
  img.className = 'inv-img';
  img.alt = 'money';

  const candidates = moneyImageCandidates(account);
  let i = 0;

  const tryNext = () => {
    if (i >= candidates.length) return;
    img.src = candidates[i++];
  };

  img.onerror = tryNext;
  tryNext();

  return img;
}

function makeInventoryImg(itemName) {
  const img = document.createElement('img');
  img.className = 'inv-img';
  img.alt = itemName;

  const candidates = inventoryImageCandidates(itemName);
  let i = 0;

  const tryNext = () => {
    if (i >= candidates.length) return;
    img.src = candidates[i++];
  };

  img.onerror = () => tryNext();
  tryNext();

  return img;
}
let countdownTimer = null;

function formatSeconds(totalSeconds) {
  totalSeconds = Math.max(0, Math.floor(Number(totalSeconds) || 0));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

function stopCountdown() {
  if (countdownTimer) {
    clearInterval(countdownTimer);
    countdownTimer = null;
  }
}

function startCountdown(seconds) {
  stopCountdown();
  let remaining = Math.max(0, Math.floor(Number(seconds) || 0));
  uiCountdown.textContent = formatSeconds(remaining);

  if (remaining <= 0) return;

  countdownTimer = setInterval(() => {
    remaining = Math.max(0, remaining - 1);
    uiCountdown.textContent = formatSeconds(remaining);
    if (remaining <= 0) stopCountdown();
  }, 1000);
}


function setIconBox(iconBox, mainReward) {
  if (!iconBox) return;

  const fallback = document.createElement('span');
  fallback.className = 'fallback-emoji';
  fallback.textContent =
    mainReward?.type === 'money' ? '💵' :
    mainReward?.type === 'weapon' ? '🔫' :
    '🎁';

  iconBox.innerHTML = '';
  iconBox.appendChild(fallback);

  if (!mainReward) return;

  if (mainReward.type === 'money') {
    const img = makeMoneyImg(mainReward.account);

    img.onload = () => {
      iconBox.innerHTML = '';
      iconBox.appendChild(img);
    };
    return;
  }

  if (mainReward.type === 'item' && mainReward.item) {
    const img = makeInventoryImg(mainReward.item);

    img.onload = () => {
      iconBox.innerHTML = '';
      iconBox.appendChild(img);
    };
    return;
  }

}


function nui(action, data = {}) {
  return fetch(`https://${resourceName()}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  }).then(r => r.json());
}

function safeText(el, text) {
  if (!el) return;
  el.textContent = text;
}

function iconForReward(r) {
  if (!r) return "🎁";
  if (r.type === "money") return "💵";
  if (r.type === "weapon") return "🔫";
  return "🎁";
}

function labelForReward(r) {
  if (!r) return "Reward";
  if (r.type === "money") return `${r.amount || 0} ${r.account || "cash"}`;
  if (r.type === "weapon") return `${r.weapon || "weapon"}`;
  return `${r.item || "item"}${r.amount && r.amount > 1 ? ` x${r.amount}` : ""}`;
}

function renderDots(total, activeIndex) {
  if (!streakDots) return;
  streakDots.innerHTML = "";

  const maxDots = 14;
  let start = 1;
  let end = total;

  if (total > maxDots) {
    start = Math.max(1, activeIndex - Math.floor(maxDots / 2));
    end = start + maxDots - 1;
    if (end > total) {
      end = total;
      start = end - maxDots + 1;
    }
  }

  for (let i = start; i <= end; i++) {
    const dot = document.createElement("div");
    dot.className = "dot" + (i === activeIndex ? " active" : "");
    dot.title = `Day ${i}`;
    streakDots.appendChild(dot);
  }
}

function renderCards(state) {
  if (!cardsContainer) return;

  const schedule = state?.schedule || [];
  const rewardIndex = state?.rewardIndex || 1;
  const canClaim = !!state?.canClaim;

  const windowSize = 8; 
  const total = schedule.length || 0;

  const start = Math.max(1, Math.min(rewardIndex - 2, total - windowSize + 1));
  const end = Math.min(total, start + windowSize - 1);

  cardsContainer.innerHTML = "";

  for (let day = start; day <= end; day++) {
    const pack = schedule[day - 1] || {};
    const main = (pack.rewards && pack.rewards[0]) || null;

    const isActive = day === rewardIndex;
    const isFuture = day > rewardIndex;
    const isLocked = isFuture; // Will Expand Soon

    const card = document.createElement("div");
    card.className = "reward-card" + (isActive ? " active" : "") + (isLocked ? " locked" : "");
    card.innerHTML = `
      <div class="card-top">
        <span class="rarity">${pack.label || "Ordinary"}</span>
        <span class="mult">${(main?.amount && main.amount > 1) ? `${main.amount}x` : "1x"}</span>
      </div>
      <div class="card-mid">
        <div class="item-icon">${iconForReward(main)}</div>
      </div>
      <div class="card-name">${labelForReward(main)}</div>
      ${isLocked ? `<div class="lock-overlay">🔒</div>` : ``}
      ${isActive ? `<div class="active-bar"></div>` : ``}
    `;
    const iconBox = card.querySelector('.item-icon');
    setIconBox(iconBox, main);

    card.addEventListener("click", () => { /* reserved */ });

    cardsContainer.appendChild(card);
  }

  renderDots(total, rewardIndex);

  btnClaim.disabled = !canClaim;
  safeText(btnClaimText, canClaim ? "Claim Reward" : "Already Claimed");
  if (btnClaimIcon) btnClaimIcon.classList.toggle("hidden", !canClaim);
}

function render(state) {
  STATE = state;

  safeText(uiPlayerNameEl, state?.playerName || "Citizen");
  safeText(uiPlanEl, "Basic Plan");

  safeText(uiStreak, String(state?.streak || 0));

  if (state?.canClaim) {
    stopCountdown();
    uiCountdown.textContent = "Available";
  } else {
  startCountdown(state?.nextRewardIn);
  }

  renderCards(state);
}

window.addEventListener("message", (event) => {
  const data = event.data;
  if (data?.action === "open") {
    app?.classList.remove("hidden");
    render(data.state);
  }
  if (data?.action === "close") {
    app?.classList.add("hidden");
  }
});

btnClose?.addEventListener("click", async () => {
  await nui("close");
  app?.classList.add("hidden");
});

btnClaim?.addEventListener("click", async () => {
  const res = await nui("claim");
  if (res?.state) render(res.state);
});

document.addEventListener("keydown", async (e) => {
  if (e.key === "Escape") {
    await nui("close");
    app?.classList.add("hidden");
  }
});
