# Agent Permanent Memory

## 1. 身份与使命 (Identity)
为南京师范大学心理学院贝叶斯统计课程（《Bayesian Statistics with Python》）制作可放映的 Quarto revealjs 课件（lec1.qmd → 16:9 HTML），核心要求：**每张 slide 内容必须在 1600×900 设计稿内单页完整显示**，R 代码真实执行，结果可信可缓存。

## 2. 铁律与工作流 (Rules & SOPs)

- **版式验证双通道**：① 静态（CSS 挂载与否必须 grep `<link>` 确认）；② 运行时用 playwright 做 DOM 数值实测，阈值 ≤897（slide 高 900）；必须 `?nocache=` 重载否则读到旧 CSS 假阴性。测法细节与三个坑见 3. 节「渲染后视觉/溢出问题排查」。
- **渲染 SOP**：用户用 Positron + `quarto preview` 实时预览（qmd 保存后约 3 s **原地**更新仓库根的 `lecN.html`）——**优先核验该产物，不必自己渲染**（原理与坑见 3. 节「渲染 qmd / 核验渲染结果」）。确需自己渲染时：① 先 `HOME=$TMPDIR/quarto_home` 重定向 sass 缓存（沙箱内否则必报 `unable to open database file`）；② 仅 `lec1.qmd` 支持 `SMOKE_TEST=true` 快速验证版式（1-2 min），其余章节无此开关；③ 长渲染（>30min）必须 `nohup ... > log 2>&1 &` 后台化、**禁止前台同步等待**（60min 必超时被 kill），并用 `pgrep -fl quarto` 核实进程（`ps` 被沙箱拒绝、`pkill` 可能静默失败）。
- **改完 qmd 并渲染出 HTML 后，必须提醒用户对齐 `.R` / `.py`**：无论 HTML 由用户的 preview 还是自己渲染产生，都要**主动提醒用户**对齐同章的 `.R` 与 `.py`（文件构成见第 4 节「文件」，对齐维度见「符号与标注约定」）；一律**以 qmd 为准**，不要等用户发现。
- **MCMC 缓存用工具原生机制**：brms 加 `file=` 参数即可（存在即加载），smoke/full 文件名必须区分（`tmpdata/xxx_smoke` vs `tmpdata/xxx`），目录入 `.gitignore`。
- 溢出修复优先级：合并多图 > 拆 slide > 全局 CSS 压字号/行距 > 截断输出加滚动（`code-overflow:scroll` 只对源码生效，**stdout 输出必须自定义 max-height**）。

## 2.5 Skills 使用指南 (Skills Guide)

| Skill | 触发场景 | 用法 |
|---|---|---|
| **quarto-pptx-creator**（项目级，`.agents/skills/`；opencode 旧路径已弃用，DSH/多 agent 均从此目录读取） | 设计新课件/新章节的 qmd 结构、把素材拆成逐页 slide、内容组织方法论 | `skill(name="quarto-pptx-creator")` 加载其流程参考；做 revealjs 时借鉴其"素材→结构化 qmd"骨架，但输出格式仍遵循本文件渲染 SOP |
| **playwright / dev-browser** | 渲染产物视觉验证、溢出检测、页面截图/操作 | 溢出检测核心工具（见 3. 节场景 1）；必须配 `browser_run_code_unsafe` 跑 DOM 测量脚本 |
| **frontend-ui-ux** | slide 视觉/布局调优（两栏、字号、图排版） | 委派 UI 类任务时 `task(category="visual-engineering", load_skills=["frontend-ui-ux"], ...)`，勿用 quick/unspecified 类 |
| **git-master** | 任何 git 操作（提交、历史检索） | `task(category="quick", load_skills=["git-master"], ...)` 委派，节省主上下文 |
| **review-work** | 较大实现完成后自查 | 委派 5 路并行审阅；本环境无图像能力，审查以数值/DOM 证据为准 |
| **ai-slop-remover** | 清理代码中的 AI 风格冗余注释 | 单文件逐个调用 |

注意：**委派任何 subagent 时都必须传 `load_skills`**（匹配的 skill 优先；无匹配传 `[]`）。图像能力受限的应对见 3. 节「视觉确认截图」。

## 3. 避坑指南 / 经验库 (Lessons Learned)

> **场景**: 渲染后视觉/溢出问题排查
> **❌ 踩坑记录**: ① DOM 全局检测把视口内正常元素误报溢出，且未排除折叠 `<details>` 内不可见 PRE；② 用 file:// 直接访问被浏览器阻止；③ 改 CSS 后复测数值原封不动=浏览器缓存（非 CSS 无效）。
> **✅ 正确姿势**: 只测当前 present slide；排除 `details:not([open])`；local bottom = `(rect.bottom - secRect.top)/Reveal.getScale()`，阈值 ≤897（slide 高 900），过滤 height≤1；起 `python3 -m http.server` 后访问；URL 加 `?nocache=timestamp` 强刷。
> **🔔 预警信号**: 数值诡异没变化 → 先查缓存；元素有 rect 但折叠 → 查 closest('details').open。

> **场景**: 调用 rstan/brms 缓存
> **❌ 踩坑记录**: 误以为 `rstan::stan(file=...)` 是结果缓存——实际 `file` 是 **Stan 模型代码路径**，传 .rds 会当代码读而报错；只有 `brms::brm(file=)` 是结果缓存（`file_refit="never"`）。
> **✅ 正确姿势**: 先 `args()`/help 核实 API 语义再下结论；smoke 与 full 采样量不同，缓存名必须区分否则 full 加载 smoke 小样本；改模型后需手动删 `tmpdata/*.rds`。
> **🔔 预警信号**: 用户说"XX 自带缓存"时，先本地验证该包参数再设计，避免直接照搬。

> **场景**: 视觉确认截图
> **❌ 踩坑记录**: 当前主模型与 multimodal-looker 用的 big-pickle **均不支持图像输入**（look_at 直接报错，agent 挂死 3min）。
> **✅ 正确姿势**: 放弃读图，全部改用精确 DOM 数值测量（block 级 local top/bottom 定位溢出元素），证据更强。
> **🔔 预警信号**: 图分析任务长时间 running → 立即 cancel，不等待。

> **场景**: 第三方 MCP 安装
> **❌ 踩坑记录**: bayes-msp 仓库代码缺失（schemas/inputs.py、outputs.py 不存在）、pyproject 包结构错误致 `pip install` 失败、`/mcp` 端点是非标准 JSON-RPC（opencode 连不上）、PyMC6 与旧代码不兼容。README 声称的 URL 与实际仓库名还不一致。
> **✅ 正确姿势**: 先 clone 完整审查 + 用标准 MCP initialize 探测协议兼容性，再决定修复/放弃，别急着写 opencode.json。
> **🔔 预警信号**: star 少（4★）的 MCP 仓库，协议与可运行性都需实测。

> **场景**: 验证含希腊字母/中文的 R 绘图代码
> **❌ 踩坑记录**: 用 `pdf()` 设备跑含 `θ` 的标签 → 报 `conversion failure ... in 'mbcsToSbcs': for θ (U+03B8)`，极易误判为"代码有编码 bug"而改坏本来正常的代码。
> **✅ 正确姿势**: Quarto/knitr 渲染 HTML 用的是 png（ragg/quartz）；实测该设备上 `strwidth("θ")=0.0184` vs `strwidth("X")=0.0221`（比例正常，非缺字方框）→ 字面 `θ` 在成品里正常。验证一律用 `png()` / `ragg::agg_png()`，**禁用 `pdf()`**。
> **🔔 预警信号**: 见到 `mbcsToSbcs` → 先换设备，别动代码。

> **场景**: 渲染 qmd / 核验渲染结果
> **❌ 踩坑记录**: ① `quarto render` 报 `unable to open database file`（`Deno.openKv`）——sass 缓存目录 `~/Library/Caches/quarto` 在工作区外不可写（`darwinUserCacheDir` 硬编码 `$HOME`，macOS 上不认 `XDG_CACHE_HOME`）；② `pkill` 静默失败 + `ps` 被沙箱拒绝，导致"以为已杀掉"的后台渲染仍在跑，并改写了 `lec3.html` 与 8 张 figure PNG。
> **✅ 正确姿势**: 优先核验**用户自己的 `quarto preview` 产物**（实测 qmd 保存后约 3 s HTML 即更新，无需自己渲染）；确需渲染时用 `HOME=$TMPDIR/quarto_home` 把缓存重定向进可写区；查进程用 `pgrep -fl quarto`（`ps` 被拒）。
> **🔔 预警信号**: 渲染"失败"但 HTML 却变了 → 是用户的 preview 在跑，不是你的进程。

> **场景**: 画 prior / likelihood / posterior 曲线
> **❌ 踩坑记录**: `prior <- dbeta(x,a,b)/sum(dbeta(x,a,b))` → y 轴变成 ~1e-4 而非密度；且先验与似然**各自除以不同常数**（÷9999 vs ÷144），两条曲线的相对高度失去意义（峰高比 0.70，正确应 1.00）。
> **✅ 正确姿势**: 真密度 + 似然缩放到与先验同高 `lik/max(lik)*max(prior)` + 后验用解析式 `dbeta(x, a+k, b+n-k)`；验证三件套：`∫=1`、后验解析式÷(先验×似然) 为常数（实测 sd=3.9e-13）、峰高比 =1.00。
> **🔔 预警信号**: 图里 y 轴标着 "Density" 但数值是 1e-4 量级 → 归一化错了。

> **场景**: 不确定脚本里某段代码该删还是该留
> **❌ 踩坑记录**: 靠代码结构猜——lec3 的数据读取段"看起来很重要"，实际下游全是硬编码 `n=50, y=30`，删掉后所有数值不变。
> **✅ 正确姿势**: 做差分实验——删掉后重跑，比对关键数值是否**逐位相同**（实测删除前后 R 均 `465 / 0.6633868`、py 均 `451 / 0.6631287`）。用实验代替争论。
> **🔔 预警信号**: 为"这段要不要留"反复讨论 → 直接做差分。

> **场景**: 连续修改同一个文件（qmd / R / py）
> **❌ 踩坑记录**: 写入一次后再 `edit` 同一文件 → 报 `file changed since it was read`；且一条消息内的多个 `edit` 都基于该消息**开始时**的快照，所以"先整体替换、再针对替换后的文本做二次编辑"这类分阶段方案在同一批内会失效。
> **✅ 正确姿势**: 每批写入后重新 `read`（**部分读取即可满足守卫**）；有依赖的两阶段替换拆到**不同消息**；一批内只做 old_string 互不重叠、且都存在于批次开始状态的编辑（可含 `replace_all`）。
> **🔔 预警信号**: 一批 edit 全部报 "file changed since it was read" → 是缺一次 read，不是路径或权限问题。

> **场景**: macOS 大小写不敏感文件系统上的批量重命名
> **❌ 踩坑记录**: git index 里存的是 `lecture13.ipynb`（小写），工作区文件却是 `Lecture13.ipynb`（大写）——APFS 上二者是同一个文件；`git ls-files --error-unmatch Lecture13.ipynb` 因大小写不匹配判定"未跟踪"，改走普通 `mv` 后 index 留下指向不存在文件的条目（`git status` 显示 `D lecture13.ipynb` + `?? lec13.ipynb`）。
> **✅ 正确姿势**: 批量改名后必须 `git status --short` **全量**核查（不能只 grep 目标前缀）；对大小写不一致的条目补 `git add <新名> && git add -A -- <旧名>`，git 会自动识别为 rename；用 `git ls-files --error-unmatch`（大小写敏感）判定跟踪状态，能暴露此类不一致。
> **🔔 预警信号**: `git status` 出现 `D <旧名>` 与 `?? <新名>` 成对 → 是大小写/改名残留，不是真的丢文件。

> **场景**: 合并各讲的 `<stem>_files/` 渲染产物到单一文件夹
> **❌ 踩坑记录**: 把 `lib-dir` / `fig-path` 写在 **format** 级（`format.revealjs.lib-dir`）或 `execute: fig-path` → **被静默忽略**（不报错、不警告，仍生成 `<stem>_files/libs` + `<stem>_files/figure-revealjs`）。实测 quarto.js 中 `fig-path`/`fig-dir` 出现 **0 次**；`lib-dir` 只作 **project** 级键被读取。
> **✅ 正确姿势**: ① 库文件用 `_quarto.yml` 的 `project: lib-dir: assets/libs`（所有讲共用一份，HTML 引用自动改写，knitr/jupyter 引擎均生效）；② 各讲的图用 setup chunk `knitr::opts_chunk$set(fig.path = "assets/figs/lecN/")`（**仅 knitr 讲**有效，图不再落地 `<stem>_files/`）；③ 项目里务必加 `project: render: ["lec*.qmd"]`，否则 `tmpdata/` 下的散落 qmd 会被一起渲染。
> **🔔 预警信号**: 配置了 `lib-dir`/`fig-path` 但目录仍叫 `<stem>_files` → 配置层级写错了，被忽略。

## 4. 上下文默认值 (Context Defaults)

- **语言**：中文交流，学术内容保留英文术语；回复精炼、多用表格/代码块，避免赘述。
- **工作目录**：真目录 `/Users/hcp4715/Library/CloudStorage/OneDrive-Personal/Teaching/Bayesian/PsyBayesian/`（OneDrive，勿动其文件结构）。
- **文件**：每章三份同源文件——`lecN.qmd`（幻灯片）+ `lecN.R` / `lecN.py`（平台版脚本）；**qmd 是脚本的子集**（脚本另有 50000 次模拟、Beta 集中度对比等）。全章共用样式 `lec.css`；数据 `data/`（`flanker_1.csv` 6.7万行、`SMS_Well_being.csv`）；手工素材图 `figs/lecN/`（lec1 14 个文件、13 个被引用）；渲染产物统一收在 `assets/`（`libs/` 共享库 + `figs/lecN/` 各讲的图），项目配置 `_quarto.yml`。
- **符号与标注约定**：参数正文一律写 math inline `$\theta$`（勿用 `` `ACC` `` / `` `theta` ``）；R/Python 代码里用 ASCII `theta`；坐标轴标签 R 用 `expression(theta)`、Python 用 `r'$\theta$'`；较长图注/图例内用字面 `θ`；区间写 `$[0,1]$` 而非 `` `[0,1]` ``。
- **环境**：R 4.5.2（R 包在系统 framework library，故重定向 `HOME` 安全）；ggplot2 **4.0.2**（实测 `geom_line(size=)` 仍生效、`..density..` 仍可用 → 无静默退化；现代写法 `linewidth` / `after_stat(density)` 同样可用）；**`preliz` 未安装**（py 脚本不能直接跑，可用 stub 顶替验证其余逻辑）；`data/evans2020JExpPsycholLearn_exp1_clean_data.csv` 253 行、`percentCoherence` 全为 5（即 5% 一致性条件）、`correct==1` 152 行 / `==0` 101 行。
- **渲染产物**：lec1 82→83 slides。产物已收拢到 `assets/`：各讲的图在 `assets/figs/lecN/`（由 setup chunk 的 `knitr::opts_chunk$set(fig.path=...)` 指定，**仅 knitr 讲** lec1/2/3），revealjs 库在 `assets/libs/`（全课共享一份，由 `_quarto.yml` 的 `project: lib-dir` 指定）；**不再生成 `lecN_files/`**。旧 `Lecture1_files/`、`Lecture2_files/` 待各自重渲染后删除。
- **工作方式**：用户会在轮次之间自行 `git commit`——动手前先 `git log` / `git status` 摸清状态。
- **引用规范**：参考文献页倾向只保留与内容直接相关条目（用户曾因"英文引用疑似错误且无关"要求删）。

## 5. 待确认事项 (Pending Clarifications)

- 全量渲染每次仍跑 rstan 例1（约 5min）——是否也要缓存（当前明确"仅 brms 缓存，rstan 照跑"）。
- lec1/lec2 尚未按新结构重渲染：旧 `Lecture1_files/`、`Lecture2_files/` 仍被各自的 html 引用，重渲染后需 `git rm -r`。
- `figs/lec1/` 中**仅 `meme.jpg`** 未被引用（14 个文件里 13 个已引用）——是否删除？
- 恢复文件 `Lecture1_backup.qmd` 保留作安全网——何时可删？
