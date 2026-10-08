<!-- Title: "Product Vision: Beyond the Black-Box Backend". Restates the existing wiki doc; the Vision wording and "What would change our mind" are proposed. -->
> level: vision · status: active · owner: qvanle
> realizes: none · depends-on: none
> start: 2026-09-16 · end: 2027-09-16 · updated: 2026-10-08

:::info
**TL;DR** Vibe-coding platforms won the frontend; we win the backend by letting a non-technical owner ==watch their own logic run==.
:::

## 🎯 Mission
To create products that genuinely help people and act as a driving force for Vietnam's social development.

## 🔭 Vision
A business owner with no technical background runs their operations on software they can see and change themselves: they
describe what they need, watch the logic run step by step, and change it without calling an agency.

---

## 🧩 The problem
Many businesses still run operations manually. The market offers three options and each fails them differently.

| Option today | Why it fails them |
| --- | --- |
| 🧑‍💻 Freelancer or agency | Slow and expensive for a simple need; every change means going back |
| 🌐 Website builders (Wix, Bluehost) | Generic; built to have a site, not to run operations |
| 🤖 Vibe-coding platforms (Lovable, Base44, v0) | Great frontends, but the backend is a black box |

:::warning
**The gap nobody fills:** none of the third group has solved backend transparency.
:::

## 💡 The belief
:::success
**We believe** ==an owner who can watch each step of their own backend will trust it, and the platforms that hide it cannot copy that cheaply.==
The falsifiable form: node-level execution tracing (payload in and out, timing, status per step) readable by a non-technical owner.
:::

## 📌 Why it matters
"It works" is not "I understand what it does to my data and my process". Transparency is the whole differentiation, not a feature.

---

## 🧪 Evidence

| Claim | Source | Tier |
| --- | --- | --- |
| Large firms use AI at 40%, small firms at 11.9% | OECD (2025), AI Adoption by SMEs, G7 paper | 🟢 |
| Opacity is structural to AI code generation | Hanson (2025), arXiv:2505.20303 | 🟡 |
| Low-code shows the same limits | J. Systems and Software reviews (2024, 2026) | 🟢 |
| Visible logic raises trust | Cheung and Ho (2025), N=1,002 | 🟢 |
| No competitor documents node-level tracing for owners | Own review of competitor docs | ⚪ |

## 🚦 What would change our mind
- [ ] A competitor ships owner-readable execution traces (Base44 is the one to watch).
- [ ] Owners rarely open the trace view after their first week.

## ❓ Open questions
- Market size (TAM, SAM, SOM) is not quantified; ICP order is undecided.
- Self-serve or sales-assisted is undecided; brand tone is undecided.

## 📝 Review notes

| Date | Change | Why |
| --- | --- | --- |
| 2026-10-08 | Header added; Mission and Vision split; layout refreshed | Alignment with the rox-workspace structure |
