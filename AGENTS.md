# Agent Permanent Memory

## 1. 身份与使命 (Identity)
为南京师范大学心理学院贝叶斯统计课程（《Bayesian Statistics with Python》）制作可放映的 Quarto revealjs 课件（Lecture1.qmd → 16:9 HTML），核心要求：**每张 slide 内容必须在 1600×900 设计稿内单页完整显示**，R 代码真实执行，结果可信可缓存。

## 2. 铁律与工作流 (Rules & SOPs)

- **版式验证双通道**：① 静态（CSS 挂载与否必须 grep `<link>` 确认）；② 运行时用 playwright 做 DOM 数值实测，阈值 ≤897（slide 高 900）；必须 `?nocache=` 重载否则读到旧 CSS 假阴性。测法细节与三个坑见 3. 节「渲染后视觉/溢出问题排查」。
- **渲染 SOP**：用户用 Positron + `quarto preview` 实时预览（qmd 保存后约 3 s **原地**更新仓库根的 `LectureN.html`）——**优先核验该产物，不必自己渲染**（原理与坑见 3. 节「渲染 qmd / 核验渲染结果」）。确需自己渲染时：① 先 `HOME=$TMPDIR/quarto_home` 重定向 sass 缓存（沙箱内否则必报 `unable to open database file`）；② 仅 `Lecture1.qmd` 支持 `SMOKE_TEST=true` 快速验证版式（1-2 min），其余章节无此开关；③ 长渲染（>30min）必须 `nohup ... > log 2>&1 &` 后台化、**禁止前台同步等待**（60min 必超时被 kill），并用 `pgrep -fl quarto` 核实进程（`ps` 被沙箱拒绝、`pkill` 可能静默失败）。
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
> **❌ 踩坑记录**: ① `quarto render` 报 `unable to open database file`（`Deno.openKv`）——sass 缓存目录 `~/Library/Caches/quarto` 在工作区外不可写（`darwinUserCacheDir` 硬编码 `$HOME`，macOS 上不认 `XDG_CACHE_HOME`）；② `pkill` 静默失败 + `ps` 被沙箱拒绝，导致"以为已杀掉"的后台渲染仍在跑，并改写了 `Lecture3.html` 与 8 张 figure PNG。
> **✅ 正确姿势**: 优先核验**用户自己的 `quarto preview` 产物**（实测 qmd 保存后约 3 s HTML 即更新，无需自己渲染）；确需渲染时用 `HOME=$TMPDIR/quarto_home` 把缓存重定向进可写区；查进程用 `pgrep -fl quarto`（`ps` 被拒）。
> **🔔 预警信号**: 渲染"失败"但 HTML 却变了 → 是用户的 preview 在跑，不是你的进程。

> **场景**: 画 prior / likelihood / posterior 曲线
> **❌ 踩坑记录**: `prior <- dbeta(x,a,b)/sum(dbeta(x,a,b))` → y 轴变成 ~1e-4 而非密度；且先验与似然**各自除以不同常数**（÷9999 vs ÷144），两条曲线的相对高度失去意义（峰高比 0.70，正确应 1.00）。
> **✅ 正确姿势**: 真密度 + 似然缩放到与先验同高 `lik/max(lik)*max(prior)` + 后验用解析式 `dbeta(x, a+k, b+n-k)`；验证三件套：`∫=1`、后验解析式÷(先验×似然) 为常数（实测 sd=3.9e-13）、峰高比 =1.00。
> **🔔 预警信号**: 图里 y 轴标着 "Density" 但数值是 1e-4 量级 → 归一化错了。

> **场景**: 不确定脚本里某段代码该删还是该留
> **❌ 踩坑记录**: 靠代码结构猜——Lecture3 的数据读取段"看起来很重要"，实际下游全是硬编码 `n=50, y=30`，删掉后所有数值不变。
> **✅ 正确姿势**: 做差分实验——删掉后重跑，比对关键数值是否**逐位相同**（实测删除前后 R 均 `465 / 0.6633868`、py 均 `451 / 0.6631287`）。用实验代替争论。
> **🔔 预警信号**: 为"这段要不要留"反复讨论 → 直接做差分。

> **场景**: 连续修改同一个文件（qmd / R / py）
> **❌ 踩坑记录**: 写入一次后再 `edit` 同一文件 → 报 `file changed since it was read`；且一条消息内的多个 `edit` 都基于该消息**开始时**的快照，所以"先整体替换、再针对替换后的文本做二次编辑"这类分阶段方案在同一批内会失效。
> **✅ 正确姿势**: 每批写入后重新 `read`（**部分读取即可满足守卫**）；有依赖的两阶段替换拆到**不同消息**；一批内只做 old_string 互不重叠、且都存在于批次开始状态的编辑（可含 `replace_all`）。
> **🔔 预警信号**: 一批 edit 全部报 "file changed since it was read" → 是缺一次 read，不是路径或权限问题。

## 4. 上下文默认值 (Context Defaults)

- **语言**：中文交流，学术内容保留英文术语；回复精炼、多用表格/代码块，避免赘述。
- **工作目录**：真目录 `/Users/hcp4715/Library/CloudStorage/OneDrive-Personal/Teaching/Bayesian/PsyBayesian/`（OneDrive，勿动其文件结构）。
- **文件**：每章三份同源文件——`LectureN.qmd`（幻灯片）+ `LectureN.R` / `LectureN.py`（平台版脚本）；**qmd 是脚本的子集**（脚本另有 50000 次模拟、Beta 集中度对比等）。全章共用样式 `lecture.css`；数据 `data/`（`flanker_1.csv` 6.7万行、`SMS_Well_being.csv`）；图 `figs/lecN/`（lec1 14 个文件、13 个被引用）。
- **符号与标注约定**：参数正文一律写 math inline `$\theta$`（勿用 `` `ACC` `` / `` `theta` ``）；R/Python 代码里用 ASCII `theta`；坐标轴标签 R 用 `expression(theta)`、Python 用 `r'$\theta$'`；较长图注/图例内用字面 `θ`；区间写 `$[0,1]$` 而非 `` `[0,1]` ``。
- **环境**：R 4.5.2（R 包在系统 framework library，故重定向 `HOME` 安全）；ggplot2 **4.0.2**（实测 `geom_line(size=)` 仍生效、`..density..` 仍可用 → 无静默退化；现代写法 `linewidth` / `after_stat(density)` 同样可用）；**`preliz` 未安装**（py 脚本不能直接跑，可用 stub 顶替验证其余逻辑）；`data/evans2020JExpPsycholLearn_exp1_clean_data.csv` 253 行、`percentCoherence` 全为 5（即 5% 一致性条件）、`correct==1` 152 行 / `==0` 101 行。
- **渲染产物**：Lecture1 82→83 slides；`Lecture1_files/figure-revealjs` 6 张 R 图（另有 9 个 `.svg` 来自 jupyter 执行）。
- **工作方式**：用户会在轮次之间自行 `git commit`——动手前先 `git log` / `git status` 摸清状态。
- **引用规范**：参考文献页倾向只保留与内容直接相关条目（用户曾因"英文引用疑似错误且无关"要求删）。

## 5. 待确认事项 (Pending Clarifications)

- 全量渲染每次仍跑 rstan 例1（约 5min）——是否也要缓存（当前明确"仅 brms 缓存，rstan 照跑"）。
- `figs/lec1/` 未纳入 git（一直 untracked）；`Lecture1.qmd/html` 亦未入库——是否整体纳入版本管理？
- `figs/lec1/` 中**仅 `meme.jpg`** 未被引用（14 个文件里 13 个已引用）——是否删除？
- 恢复文件 `Lecture1_backup.qmd` 保留作安全网——何时可删？
